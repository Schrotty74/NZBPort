import Foundation

/// Public JSON API: https://nzbindex.com/api
public actor NZBIndexClient: NZBSearchProvider {
    nonisolated public var name: String { "NZBIndex" }
    private let transport: any HTTPTransport
    private let base = URL(string: "https://nzbindex.com/api")!

    public init(transport: any HTTPTransport = SessionTransport()) { self.transport = transport }

    public func resolve(_ link: NZBLink) async throws -> URL {
        var query = URLComponents(url: base.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        query.queryItems = [URLQueryItem(name: "q", value: link.header),
                            URLQueryItem(name: "max", value: "25")]
            + link.groups.map { URLQueryItem(name: "groups", value: indexGroupName($0)) }
        var request = URLRequest(url: query.url!)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let result: HTTPResult
        do { result = try await transport.perform(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw RelayError.message("NZBIndex is unavailable. Check the search service and network connection.") }
        try Task.checkCancellation()
        guard (200..<300).contains(result.status) else {
            throw RelayError.message("NZBIndex returned HTTP \(result.status). Please try again later.")
        }
        let envelope: SearchResponse
        do { envelope = try JSONDecoder().decode(SearchResponse.self, from: result.data) }
        catch { throw RelayError.message("NZBIndex returned an invalid JSON search response.") }
        guard envelope.error != true, let entries = envelope.data?.content else {
            throw RelayError.message("NZBIndex rejected the search. Please try again later.")
        }
        var ids = Set<String>()
        let candidates = entries.filter { ids.insert($0.id).inserted }
        guard !candidates.isEmpty else { throw RelayError.message("NZBIndex found no NZB for this link.") }
        // A unique header identifies one collection. Never merge unrelated hits.
        guard candidates.count == 1, let candidate = candidates.first else {
            throw RelayError.message("The search identifier returned multiple NZBs. The link is ambiguous; nothing was sent to SABnzbd.")
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !candidate.id.isEmpty, candidate.id.count <= 128,
              candidate.id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw RelayError.message("NZBIndex returned an invalid result identifier.")
        }
        return base.appendingPathComponent("download").appendingPathComponent(candidate.id + ".nzb")
    }

    private func indexGroupName(_ group: String) -> String {
        let name = group.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased().hasPrefix("a.b.") {
            return "alt.binaries." + name.dropFirst(4)
        }
        return name
    }
}

private struct SearchResponse: Decodable {
    struct Page: Decodable {
        struct Collection: Decodable { let id: String }
        let content: [Collection]
    }
    let data: Page?
    let error: Bool?
}
