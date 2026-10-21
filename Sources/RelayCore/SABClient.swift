import Foundation

/// Minimal client for the SABnzbd HTTP API.
public actor SABClient {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = SessionTransport()) {
        self.transport = transport
    }

    public func categories(_ connection: ServerConnection) async throws -> [String] {
        let data = try await request(
            connection,
            fields: [("mode", "get_cats")],
            failureMessage: "SABnzbd could not retrieve the categories."
        )
        let payload = try decode(data, as: CategoriesResponse.self)
        if let error = payload.error {
            throw RelayError.message("SABnzbd: \(error)")
        }
        guard let categories = payload.categories else {
            throw RelayError.message("SABnzbd returned an invalid response to the category request.")
        }
        var seen = Set<String>()
        return categories.filter { seen.insert($0).inserted }
    }

    public func send(
        _ link: NZBLink,
        download: URL,
        category: String,
        connection: ServerConnection
    ) async throws {
        var fields = [
            ("mode", "addurl"),
            ("name", download.absoluteString),
            ("nzbname", link.title),
            ("cat", category)
        ]
        if let password = link.password {
            fields.append(("password", password))
        }

        let data = try await request(
            connection,
            fields: fields,
            failureMessage: "The connection to SABnzbd was interrupted. The download status is unknown; check the SABnzbd queue."
        )
        let payload = try decode(data, as: AddURLResponse.self)
        if let error = payload.error {
            throw RelayError.message("SABnzbd: \(error)")
        }
        guard payload.status == true, let ids = payload.nzoIDs, !ids.isEmpty else {
            throw RelayError.message("SABnzbd did not confirm the download. Check the SABnzbd queue.")
        }
    }

    private func request(
        _ connection: ServerConnection,
        fields: [(String, String)],
        failureMessage: String.LocalizationValue
    ) async throws -> Data {
        var request = URLRequest(url: connection.endpoint)
        request.timeoutInterval = 25
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = FormEncoding.encode(fields + [("output", "json"), ("apikey", connection.apiKey)])

        do {
            let result = try await transport.perform(request)
            guard (200..<300).contains(result.status) else {
                throw RelayError.message("SABnzbd returned HTTP status \(result.status).")
            }
            return result.data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw RelayError.message(failureMessage)
        } catch let error as RelayError {
            throw error
        } catch {
            throw RelayError.message(failureMessage)
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw RelayError.message("SABnzbd returned an invalid JSON response.")
        }
    }
}

private struct CategoriesResponse: Decodable {
    let categories: [String]?
    let error: String?
}

private struct AddURLResponse: Decodable {
    let status: Bool?
    let nzoIDs: [String]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case status
        case nzoIDs = "nzo_ids"
        case error
    }
}
