import Foundation

/// Client for the SABnzbd HTTP API.
public actor SABClient {
    private let transport: any HTTPTransport
    public init(transport: any HTTPTransport = SessionTransport()) { self.transport = transport }

    public func categories(_ connection: ServerConnection, loginProbe: Bool = false) async throws -> [String] {
        let data = try await request(connection, fields: [("mode", "get_cats")],
                                     failureMessage: "SABnzbd could not retrieve the categories.", loginProbe: loginProbe)
        let payload = try decode(data, as: CategoriesResponse.self)
        if let error = payload.error { throw RelayError.message("SABnzbd: \(error)") }
        guard let categories = payload.categories else { throw RelayError.message("SABnzbd returned an invalid response to the category request.") }
        var seen = Set<String>(); return categories.filter { seen.insert($0).inserted }
    }

    /// Creates one SABnzbd category using SAB's own defaults for its options.
    /// This first reads the live category configuration and refuses to update an
    /// existing category, since SAB's set_config endpoint also updates by name.
    public func createCategory(_ name: String, connection: ServerConnection) async throws {
        let categoryName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryName.isEmpty,
              categoryName.count <= 64,
              !categoryName.contains("*"),
              !categoryName.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw RelayError.message("Enter a category name of 1 to 64 characters without an asterisk or control characters.")
        }

        let currentData = try await request(connection, fields: [
            ("mode", "get_config"), ("section", "categories")
        ], failureMessage: "SABnzbd could not check the current categories before creating one.")
        let current = try decode(currentData, as: CategoryConfigurationResponse.self)
        if let error = current.error { throw RelayError.message("SABnzbd: \(error)") }
        guard let currentCategories = current.config?.categories,
              !currentCategories.isEmpty,
              currentCategories.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RelayError.message("SABnzbd returned an invalid category configuration.")
        }
        guard !currentCategories.contains(where: { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }) else {
            throw RelayError.message("A category with this name already exists in SABnzbd.")
        }

        var req = URLRequest(url: connection.endpoint)
        req.timeoutInterval = 25
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = FormEncoding.encode([
            ("mode", "set_config"), ("section", "categories"),
            ("name", categoryName), ("output", "json"), ("apikey", connection.apiKey)
        ])

        let data: Data
        do {
            data = try await perform(req, failureMessage: categoryCreateUnknownFailure)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            // Any transport or HTTP failure can happen after the server saved it.
            throw RelayError.message(categoryCreateUnknownFailure)
        }
        let response: CategoryConfigurationResponse
        do {
            response = try decode(data, as: CategoryConfigurationResponse.self)
        } catch {
            throw RelayError.message(categoryCreateUnknownFailure)
        }
        if let error = response.error { throw RelayError.message("SABnzbd: \(error)") }
        guard response.config?.categories?.contains(where: {
            $0.name.caseInsensitiveCompare(categoryName) == .orderedSame
        }) == true else {
            throw RelayError.message(categoryCreateUnknownFailure)
        }
    }

    /// Deletes one existing SABnzbd category. The built-in `*` category is
    /// protected because SABnzbd replaces its default categories if it is deleted.
    /// A configuration read before and after the write prevents accidental
    /// deletion of a missing category and confirms the resulting state.
    public func deleteCategory(_ name: String, connection: ServerConnection) async throws {
        let requestedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedName.isEmpty, requestedName != "*" else {
            throw RelayError.message("The default SABnzbd category cannot be deleted.")
        }

        let currentData = try await request(connection, fields: [
            ("mode", "get_config"), ("section", "categories")
        ], failureMessage: "SABnzbd could not check the current categories before deleting one.")
        let current = try decode(currentData, as: CategoryConfigurationResponse.self)
        if let error = current.error { throw RelayError.message("SABnzbd: \(error)") }
        guard let currentCategories = current.config?.categories,
              !currentCategories.isEmpty,
              currentCategories.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RelayError.message("SABnzbd returned an invalid category configuration.")
        }
        guard let existing = currentCategories.first(where: {
            $0.name.caseInsensitiveCompare(requestedName) == .orderedSame
        }) else {
            throw RelayError.message("This category no longer exists in SABnzbd.")
        }
        let categoryName = existing.name
        guard categoryName != "*" else {
            throw RelayError.message("The default SABnzbd category cannot be deleted.")
        }

        let unknownMessage: String.LocalizationValue = "The connection to SABnzbd was interrupted while deleting the category. Its status is unknown; refresh the category list before trying again."
        let writeData: Data
        do {
            writeData = try await request(connection, fields: [
                ("mode", "del_config"), ("section", "categories"), ("keyword", categoryName)
            ], failureMessage: unknownMessage)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            // The request may have reached SABnzbd even if its response was lost.
            throw RelayError.message(unknownMessage)
        }

        let writeResponse: CategoryDeletionResponse
        do {
            writeResponse = try decode(writeData, as: CategoryDeletionResponse.self)
        } catch {
            throw RelayError.message(unknownMessage)
        }
        if let error = writeResponse.error { throw RelayError.message("SABnzbd: \(error)") }
        guard writeResponse.status == true else { throw RelayError.message(unknownMessage) }

        // SAB documents a generic status response that can be true even when
        // an operation failed, so only the refreshed configuration confirms deletion.
        let updatedCategories: [CategoryConfigurationEntry]
        do {
            let updatedData = try await request(connection, fields: [
                ("mode", "get_config"), ("section", "categories")
            ], failureMessage: unknownMessage)
            let updated = try decode(updatedData, as: CategoryConfigurationResponse.self)
            if let error = updated.error { throw RelayError.message("SABnzbd: \(error)") }
            guard let categories = updated.config?.categories,
                  !categories.isEmpty,
                  categories.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw RelayError.message(unknownMessage)
            }
            updatedCategories = categories
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is RelayError {
            throw RelayError.message(unknownMessage)
        } catch {
            throw RelayError.message(unknownMessage)
        }

        guard !updatedCategories.contains(where: {
            $0.name.caseInsensitiveCompare(categoryName) == .orderedSame
        }) else {
            throw RelayError.message("SABnzbd did not remove the category. Refresh the category list and try again.")
        }
    }

    @discardableResult public func send(_ link: NZBLink, download: URL, category: String, connection: ServerConnection, options: SendOptions = SendOptions()) async throws -> [String] {
        var fields = [("mode", "addurl"), ("name", download.absoluteString), ("nzbname", link.title), ("cat", category), ("priority", String(options.addPaused ? -2 : options.priority.rawValue))]
        if let password = link.password { fields.append(("password", password)) }
        let data = try await request(connection, fields: fields, failureMessage: unknownSendFailure)
        return try confirmedIDs(data)
    }

    @discardableResult public func send(_ file: NZBFile, category: String, connection: ServerConnection,
                                        options: SendOptions = SendOptions(), title: String? = nil,
                                        password: String? = nil) async throws -> [String] {
        let boundary = "NZBRelay-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) { body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)) }
        field("mode", "addfile"); field("output", "json"); field("apikey", connection.apiKey)
        field("cat", category); field("nzbname", title ?? file.title); field("priority", String(options.addPaused ? -2 : options.priority.rawValue))
        if let password { field("password", password) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"name\"; filename=\"\(file.title).nzb\"\r\nContent-Type: application/x-nzb\r\n\r\n".utf8))
        body.append(file.data); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var req = URLRequest(url: connection.endpoint); req.timeoutInterval = 25; req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept"); req.httpBody = body
        return try confirmedIDs(await perform(req, failureMessage: unknownSendFailure))
    }

    public func queue(_ connection: ServerConnection) async throws -> SABQueueSnapshot {
        let data = try await request(connection, fields: [("mode", "queue")], failureMessage: "SABnzbd could not retrieve the queue.")
        let p = try decode(data, as: QueueResponse.self)
        if let error = p.error { throw RelayError.message("SABnzbd: \(error)") }
        guard let q = p.queue else { throw RelayError.message("SABnzbd returned an invalid queue response.") }
        let jobs = (q.slots ?? []).compactMap { s -> SABJob? in
            guard let id = s.id else { return nil }
            return SABJob(id: id, title: s.title ?? "", status: s.status ?? "", progress: (Double(s.percentage ?? "0") ?? 0) / 100, category: s.category ?? "")
        }
        return SABQueueSnapshot(jobs: jobs, speed: q.speed ?? "", timeLeft: q.timeLeft ?? "", paused: q.paused == true || q.pausedAll == true, remainingSize: q.remainingSize ?? "")
    }

    public func history(_ connection: ServerConnection, limit: Int = 10) async throws -> [SABHistoryJob] {
        let data = try await request(connection, fields: [("mode", "history"), ("limit", String(max(0, limit)))], failureMessage: "SABnzbd could not retrieve history.")
        let p = try decode(data, as: HistoryResponse.self)
        if let error = p.error { throw RelayError.message("SABnzbd: \(error)") }
        guard let h = p.history else { throw RelayError.message("SABnzbd returned an invalid history response.") }
        return (h.slots ?? []).compactMap { s in
            guard let id = s.id else { return nil }
            let status = s.status ?? ""
            return SABHistoryJob(id: id, title: s.title ?? "", status: status, failed: status.lowercased() == "failed")
        }
    }

    public func setQueue(_ action: SABQueueAction, connection: ServerConnection) async throws {
        let data = try await request(connection, fields: [("mode", action == .pause ? "pause" : "resume")], failureMessage: "SABnzbd could not update the queue.")
        try validateStatus(data)
    }
    public func setJob(_ action: SABQueueAction, id: String, connection: ServerConnection) async throws {
        let data = try await request(connection, fields: [("mode", "queue"), ("name", action == .pause ? "pause" : "resume"), ("value", id)], failureMessage: "SABnzbd could not update the job.")
        try validateStatus(data)
    }

    private let unknownSendFailure: String.LocalizationValue = "The connection to SABnzbd was interrupted. The download status is unknown; check the SABnzbd queue."
    private let categoryCreateUnknownFailure: String.LocalizationValue = "The connection to SABnzbd was interrupted while creating the category. Its status is unknown; refresh the category list before trying again."
    private func confirmedIDs(_ data: Data) throws -> [String] {
        let p = try decode(data, as: AddResponse.self)
        if let error = p.error { throw RelayError.message("SABnzbd: \(error)") }
        guard p.status == true, let ids = p.ids, !ids.isEmpty else { throw RelayError.message("SABnzbd did not confirm the download. Check the SABnzbd queue.") }
        return ids
    }
    private func validateStatus(_ data: Data) throws {
        let p = try decode(data, as: StatusResponse.self)
        if let error = p.error { throw RelayError.message("SABnzbd: \(error)") }
        guard p.status == true else { throw RelayError.message("SABnzbd did not confirm the requested action.") }
    }
    private func request(_ connection: ServerConnection, fields: [(String, String)], failureMessage: String.LocalizationValue, loginProbe: Bool = false) async throws -> Data {
        var req = URLRequest(url: connection.endpoint); req.timeoutInterval = loginProbe ? 5 : 25; req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = FormEncoding.encode(fields + [("output", "json"), ("apikey", connection.apiKey)])
        return try await perform(req, failureMessage: failureMessage, loginProbe: loginProbe)
    }
    private func perform(_ req: URLRequest, failureMessage: String.LocalizationValue, loginProbe: Bool = false) async throws -> Data {
        do {
            let result = try await transport.perform(req)
            if loginProbe, [502, 503, 504].contains(result.status) {
                throw RelayError.retryableCategoryRead("SABnzbd returned HTTP status \(result.status).")
            }
            guard (200..<300).contains(result.status) else { throw RelayError.message("SABnzbd returned HTTP status \(result.status).") }
            return result.data
        } catch is CancellationError { throw CancellationError() }
        catch let e as URLError where e.code == .cancelled { throw CancellationError() }
        catch let e as URLError where loginProbe && [
            .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet,
            .cannotFindHost, .dnsLookupFailed
        ].contains(e.code) { throw RelayError.retryableCategoryRead(failureMessage) }
        catch let e as URLError where e.code == .timedOut { throw RelayError.message(failureMessage) }
        catch let e as RelayError { throw e }
        catch { throw RelayError.message(failureMessage) }
    }
    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw RelayError.message("SABnzbd returned an invalid JSON response.") }
    }
}

private struct CategoriesResponse: Decodable { let categories: [String]?; let error: String? }
private struct CategoryConfigurationResponse: Decodable {
    let config: CategoryConfiguration?
    let error: String?
}
private struct CategoryConfiguration: Decodable { let categories: [CategoryConfigurationEntry]? }
private struct CategoryConfigurationEntry: Decodable { let name: String }
private struct CategoryDeletionResponse: Decodable { let status: Bool?; let error: String? }
private struct AddResponse: Decodable { let status: Bool?; let ids: [String]?; let error: String?; enum CodingKeys: String, CodingKey { case status, ids = "nzo_ids", error } }
private struct StatusResponse: Decodable { let status: Bool?; let error: String? }
private struct QueueResponse: Decodable { let queue: QueueData?; let error: String? }
private struct QueueData: Decodable {
    let slots: [QueueSlot]?; let speed: String?; let timeLeft: String?; let paused: Bool?; let pausedAll: Bool?; let remainingSize: String?
    enum CodingKeys: String, CodingKey { case slots, speed, timeLeft = "timeleft", paused, pausedAll = "paused_all", remainingSize = "sizeleft" }
}
private struct QueueSlot: Decodable {
    let id: String?; let title: String?; let status: String?; let percentage: String?; let category: String?
    enum CodingKeys: String, CodingKey { case id = "nzo_id", title = "filename", status, percentage, category = "cat" }
}
private struct HistoryResponse: Decodable { let history: HistoryData?; let error: String? }
private struct HistoryData: Decodable { let slots: [HistorySlot]? }
private struct HistorySlot: Decodable { let id: String?; let title: String?; let status: String?; enum CodingKeys: String, CodingKey { case id = "nzo_id", title = "name", status } }
