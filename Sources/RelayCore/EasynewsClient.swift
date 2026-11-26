import Foundation

/// Searches by NZBlnk header and downloads the first complete file group as an NZB.
public struct EasynewsClient: Sendable {
    private static let host = "members.easynews.com"
    private static let endpoint = "https://" + host
    private let transport: any HTTPTransport

    public init?(username: String, password: String, transport: (any HTTPTransport)? = nil) {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty, !username.contains(":"),
              !username.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !password.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
        self.transport = transport ?? EasynewsTransport(host: Self.host, username: username, password: password)
    }

    public func fetch(_ link: NZBLink) async throws -> NZBFile {
        var search = URLComponents(string: Self.endpoint + "/2.0/search/solr-search/")!
        let query = FormEncoding.encode([
            ("fly", "2"), ("pby", "1000"), ("pno", "1"), ("sS", "0"), ("st", "adv"),
            ("safeO", "0"), ("sb", "1"), ("s1", "dtime"), ("s1d", "-"),
            ("s2", "nsubject"), ("s2d", "+"), ("s3", "nrfile"), ("s3d", "+"), ("sbj", link.header)
        ])
        search.percentEncodedQuery = String(decoding: query, as: UTF8.self)
        let response = try await perform(request(url: search.url!, accept: "application/json"), phase: .search)
        guard let results = try? JSONDecoder().decode(SearchResponse.self, from: response) else {
            throw RelayError.message("Easynews returned an invalid search response.")
        }
        guard let first = results.data.first(where: { $0.group?.isEmpty == false }),
              let group = first.group else { throw RelayError.message("Easynews found no matching NZB.") }

        let boundary = UUID().uuidString
        var parts = ["--\(boundary)\r\nContent-Disposition: form-data; name=\"autoNZB\"\r\n\r\n1\r\n"]
        for (index, item) in results.data.filter({ $0.group == group }).enumerated() {
            guard let id = item.id, !id.isEmpty, !id.contains("|"), let name = item.filename,
                  let ext = item.fileExtension, let signature = item.signature, !signature.isEmpty,
                  !signature.contains("\""), !signature.contains("\\"),
                  !signature.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                  !id.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
                throw RelayError.message("Easynews returned an invalid search response.")
            }
            let filename = [name, ext].map {
                Data($0.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
            }.joined(separator: ":")
            parts.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(index)&sig=\(signature)\"\r\n\r\n\(id)|\(filename)\r\n")
        }
        parts.append("--\(boundary)--\r\n")

        var download = request(url: URL(string: Self.endpoint + "/2.0/api/dl-nzb")!,
                               accept: "application/x-nzb, application/xml, text/xml")
        download.httpMethod = "POST"
        download.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        download.httpBody = Data(parts.joined().utf8)
        return try await NZBFile(data: perform(download, phase: .download), filename: "Easynews.nzb", requiresFiles: true)
    }

    private func request(url: URL, accept: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(NewznabClient.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private enum RequestPhase { case search, download }

    private func perform(_ request: URLRequest, phase: RequestPhase) async throws -> Data {
        try Task.checkCancellation()
        let result: HTTPResult
        do { result = try await transport.perform(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw RelayError.message("Easynews could not be reached.") }
        try Task.checkCancellation()
        switch (phase, result.status) {
        case (_, 200..<300):
            return result.data
        case (.search, 401):
            throw RelayError.message("Easynews rejected the sign-in during search (HTTP 401).")
        case (.download, 401):
            throw RelayError.message("Easynews rejected the sign-in during NZB download (HTTP 401).")
        case (.search, 403):
            throw RelayError.message("Easynews denied the search request (HTTP 403).")
        case (.download, 403):
            throw RelayError.message("Easynews denied the NZB download (HTTP 403).")
        case (.search, let status):
            throw RelayError.message("Easynews could not complete the search (HTTP \(status)).")
        case (.download, let status):
            throw RelayError.message("Easynews could not download the NZB file (HTTP \(status)).")
        }
    }

    private struct SearchResponse: Decodable {
        var data: [Item]
    }

    private struct Item: Decodable {
        let id: String?
        let filename: String?
        let fileExtension: String?
        let numericGroup: String?
        let namedGroup: String?
        let signature: String?

        var group: String? {
            if let namedGroup, !namedGroup.isEmpty { return namedGroup }
            return numericGroup
        }

        private enum CodingKeys: String, CodingKey {
            case id = "0"
            case filename = "10"
            case fileExtension = "11"
            case numericGroup = "19"
            case namedGroup = "setid"
            case signature = "sig"
        }
    }
}

final class EasynewsTransport: NSObject, HTTPTransport, URLSessionTaskDelegate {
    private let host: String
    private let username: String
    private let password: String

    init(host: String, username: String, password: String) {
        self.host = host
        self.username = username
        self.password = password
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return HTTPResult(data: data, status: http.statusCode)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard !space.isProxy(), space.host == host, space.protocol == "https", space.port == 443,
              challenge.previousFailureCount == 0 else {
            completionHandler(.rejectProtectionSpace, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(user: username, password: password, persistence: .none))
    }

    // Every authenticated request is built locally for the fixed Easynews HTTPS host.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
