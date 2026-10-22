import Foundation

/// Client for the SABnzbd HTTP API.
public actor SABClient {
    private let transport: any HTTPTransport
    public init(transport: any HTTPTransport = SessionTransport()) { self.transport = transport }

    public func categories(_ connection: ServerConnection) async throws -> [String] {
        let data = try await request(connection, fields: [("mode", "get_cats")], failureMessage: "SABnzbd could not retrieve the categories.")
        let payload = try decode(data, as: CategoriesResponse.self)
        if let error = payload.error { throw RelayError.message("SABnzbd: \(error)") }
        guard let categories = payload.categories else { throw RelayError.message("SABnzbd returned an invalid response to the category request.") }
        var seen = Set<String>(); return categories.filter { seen.insert($0).inserted }
    }

    @discardableResult public func send(_ link: NZBLink, download: URL, category: String, connection: ServerConnection, options: SendOptions = SendOptions()) async throws -> [String] {
        var fields = [("mode", "addurl"), ("name", download.absoluteString), ("nzbname", link.title), ("cat", category), ("priority", String(options.addPaused ? -2 : options.priority.rawValue))]
        if let password = link.password { fields.append(("password", password)) }
        let data = try await request(connection, fields: fields, failureMessage: unknownSendFailure)
        return try confirmedIDs(data)
    }

    @discardableResult public func send(_ file: NZBFile, category: String, connection: ServerConnection, options: SendOptions = SendOptions()) async throws -> [String] {
        let boundary = "NZBRelay-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) { body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)) }
        field("mode", "addfile"); field("output", "json"); field("apikey", connection.apiKey)
        field("cat", category); field("nzbname", file.title); field("priority", String(options.addPaused ? -2 : options.priority.rawValue))
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
    private func request(_ connection: ServerConnection, fields: [(String, String)], failureMessage: String.LocalizationValue) async throws -> Data {
        var req = URLRequest(url: connection.endpoint); req.timeoutInterval = 25; req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = FormEncoding.encode(fields + [("output", "json"), ("apikey", connection.apiKey)])
        return try await perform(req, failureMessage: failureMessage)
    }
    private func perform(_ req: URLRequest, failureMessage: String.LocalizationValue) async throws -> Data {
        do {
            let result = try await transport.perform(req)
            guard (200..<300).contains(result.status) else { throw RelayError.message("SABnzbd returned HTTP status \(result.status).") }
            return result.data
        } catch is CancellationError { throw CancellationError() }
        catch let e as URLError where e.code == .cancelled { throw CancellationError() }
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
