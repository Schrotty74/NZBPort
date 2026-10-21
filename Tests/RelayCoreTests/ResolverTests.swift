import Foundation
import Testing
@testable import RelayCore

private actor SearchTransport: HTTPTransport {
    private var replies: [Result<HTTPResult, URLError>]
    private var captured: [URLRequest] = []
    init(_ bodies: [String]) {
        replies = bodies.map { .success(HTTPResult(data: Data($0.utf8), status: 200)) }
    }
    init(cancelled: Bool) { replies = [.failure(URLError(.cancelled))] }
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        captured.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        return try replies.removeFirst().get()
    }
    func requests() -> [URLRequest] { captured }
}

@Test func indexSuccessDoesNotContactOtherProviders() async throws {
    let transport = SearchTransport([#"{"data":{"content":[{"id":"test-id"}]},"error":false}"#])
    let result = try await NZBResolver(transport: transport).resolve(NZBLink("nzblnk:?h=fixture"))
    #expect(result.host == "nzbindex.com")
    #expect(await transport.requests().count == 1)
}

@Test func kingFallbackSelectsSameOriginLinkAndPreservesEntities() async throws {
    let transport = SearchTransport([
        #"{"data":{"content":[]},"error":false}"#,
        #"<script>const bad='<a href="/nzb:fake">';</script><a href="https://evil.example/nzb:fake">x</a><a HREF='/nzb:fixture/?x=1&amp;y=2'>NZB</a>"#
    ])
    let result = try await NZBResolver(transport: transport).resolve(NZBLink("nzblnk:?h=fixture"))
    #expect(result.absoluteString == "https://www.nzbking.com/nzb:fixture/?x=1&y=2")
    #expect(await transport.requests().map { $0.url?.host } == ["nzbindex.com", "www.nzbking.com"])
}

@Test func binsearchFallbackUsesRealGETFormAndOnlyFirstEnabledSelection() async throws {
    let transport = SearchTransport([
        "invalid JSON", "<html>No results</html>",
        #"<input type=checkbox name=outside><form action='https://evil.example/nzb'><input type=checkbox name=bad></form><form action='/nzb' method='GET'><input type=hidden name=q value='fixture &amp; more'><input disabled type=checkbox name=disabled><input type=checkbox name=first><input type=checkbox name=second></form>"#
    ])
    let result = try await NZBResolver(transport: transport).resolve(NZBLink("nzblnk:?h=fixture"))
    let components = try #require(URLComponents(url: result, resolvingAgainstBaseURL: false))
    #expect(components.host == "www.binsearch.info")
    #expect(components.path == "/nzb")
    #expect(components.queryItems == [URLQueryItem(name: "q", value: "fixture & more"), URLQueryItem(name: "first", value: "on")])
    #expect(await transport.requests().count == 3)
}

@Test func providerExhaustionReportsEveryAttempt() async throws {
    let transport = SearchTransport(["{}", "<html></html>", "<html></html>"])
    do {
        _ = try await NZBResolver(transport: transport).resolve(NZBLink("nzblnk:?h=fixture"))
        Issue.record("Empty search results must not become a download.")
    } catch {
        #expect(error.localizedDescription.contains("NZBIndex:"))
        #expect(error.localizedDescription.contains("NZBKing:"))
        #expect(error.localizedDescription.contains("BinSearch:"))
    }
    #expect(await transport.requests().count == 3)
}

@Test func cancellationDoesNotStartAnotherSearch() async throws {
    let transport = SearchTransport(cancelled: true)
    await #expect(throws: CancellationError.self) {
        try await NZBResolver(transport: transport).resolve(NZBLink("nzblnk:?h=fixture"))
    }
    #expect(await transport.requests().count == 1)
}

@Test func resolvedFallbackDownloadIsPassedToSABWithCategoryAndTitle() async throws {
    let transport = SearchTransport([
        #"{"data":{"content":[]},"error":false}"#,
        #"<a href='/nzb:fixture/'>download</a>"#,
        #"{"status":true,"nzo_ids":["test-job"]}"#
    ])
    let link = try NZBLink("nzblnk:?h=fixture&t=Test+Package&p=test-password")
    let download = try await NZBResolver(transport: transport).resolve(link)
    try await SABClient(transport: transport).send(link, download: download, category: "test-category",
        connection: ServerConnection(address: "https://sab.example/api", apiKey: "test-only-key"))
    let requests = await transport.requests()
    let last = try #require(requests.last)
    let body = String(decoding: try #require(last.httpBody), as: UTF8.self).replacingOccurrences(of: "+", with: "%20")
    let items = try #require(URLComponents(string: "https://example.invalid/?" + body)?.queryItems)
    #expect(items.first { $0.name == "name" }?.value == "https://www.nzbking.com/nzb:fixture/")
    #expect(items.first { $0.name == "cat" }?.value == "test-category")
    #expect(items.first { $0.name == "nzbname" }?.value == "Test Package")
    #expect(items.first { $0.name == "password" }?.value == "test-password")
    #expect(last.url?.query == nil)
}
