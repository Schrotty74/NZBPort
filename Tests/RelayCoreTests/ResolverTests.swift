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
    let treasureMaps = NewznabClient(apiKey: "test-treasure-key", service: .treasureMaps, transport: transport)
    let newzBay = NewznabClient(apiKey: "test-newzbay-key", service: .newzBay, transport: transport)
    let result = try await NZBResolver(transport: transport, newznabClients: [treasureMaps, newzBay])
        .resolve(NZBLink("nzblnk:?h=fixture&t=Fixture+Episode"))
    #expect(result.host == "nzbindex.com")
    #expect(await transport.requests().count == 1)
}

@Test func exportUsesSavedIndexerOrderAndSkipsDisabledAndUnconfiguredServices() async throws {
    let preferences = try JSONDecoder().decode(IndexerPreferences.self, from: Data("""
        {"order":["Unknown","Treasure Maps","NewzBay","NewzBay","NZBKing"],"disabled":["NZBIndex","Unknown"]}
        """.utf8))
    #expect(Array(preferences.order.prefix(3)) == [.treasureMaps, .newzBay, .nzbKing])
    #expect(preferences.order.count == IndexerPreferences.Indexer.allCases.count)
    #expect(preferences.disabled == [.nzbIndex])

    let transport = SearchTransport(["<rss><channel></channel></rss>", "<a href='/nzb:fixture/'>NZB</a>", "<nzb/>"])
    let client = NewznabClient(apiKey: "test-only-key", service: .newzBay, transport: transport)
    let resolver = NZBResolver(transport: transport, newznabClients: [client], preferences: preferences)
    let link = try NZBLink("nzblnk:?h=fixture&t=Fixture")
    let file = try await resolver.fileForExport(link)
    #expect(file.data == Data("<nzb/>".utf8))
    #expect(await transport.requests().map { $0.url?.host } == ["newzbay.cc", "www.nzbking.com", "www.nzbking.com"])
}

@Test func searchingWithAllPublicIndexersDisabledMakesNoRequests() async throws {
    var preferences = IndexerPreferences()
    for indexer in [IndexerPreferences.Indexer.nzbIndex, .nzbKing, .binSearch] {
        preferences.setEnabled(false, for: indexer)
    }
    let transport = SearchTransport([])
    let resolver = NZBResolver(transport: transport, preferences: preferences)
    await #expect(throws: RelayError.self) {
        try await resolver.resolve(NZBLink("nzblnk:?h=fixture&t=Fixture"))
    }
    #expect(await transport.requests().isEmpty)
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

@Test func treasureMapsIsLastAndSABReceivesTheNZBFileWithoutTheSearchKey() async throws {
    let id = "0123456789abcdef0123456789abcdef"
    let apiKey = "test-treasure-key"
    let downloadURL = "https://file.treasure-maps.com/getnzb/\(id)?r=\(apiKey)"
    let nzb = "<nzb><file/></nzb>"
    let transport = SearchTransport([
        #"{"data":{"content":[]},"error":false}"#,
        "<html>No results</html>",
        "<html>No results</html>",
        """
        <rss xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/" version="2.0">
          <channel><newznab:response offset="0" total="1"/><item>
            <title>Test.Package.S01E07.GERMAN-Team</title>
            <guid isPermaLink="true">https://treasure-maps.com/details/\(id)</guid>
            <enclosure url="\(downloadURL)" length="100" type="application/x-nzb"/>
            <newznab:attr name="guid" value="\(id)"/>
          </item></channel>
        </rss>
        """,
        nzb,
        #"{"status":true,"nzo_ids":["test-job"]}"#
    ])
    let link = try NZBLink("nzblnk:?h=fixture&t=Test+Package+S01E07+GERMAN-Team&p=test-password")
    let treasureMaps = NewznabClient(apiKey: apiKey, service: .treasureMaps, transport: transport)
    let newzBay = NewznabClient(apiKey: "test-newzbay-key", service: .newzBay, transport: transport)
    let resolver = NZBResolver(transport: transport, newznabClients: [treasureMaps, newzBay])
    let download = try await resolver.resolve(link)
    let file = try #require(await resolver.fetchFile(download))
    try await SABClient(transport: transport).send(file, category: "test-category",
        connection: ServerConnection(address: "https://sab.example/api", apiKey: "test-only-key"),
        options: SendOptions(addPaused: true), title: link.title, password: link.password)
    let requests = await transport.requests()
    #expect(requests.map { $0.url?.host } == [
        "nzbindex.com", "www.nzbking.com", "www.binsearch.info", "treasure-maps.com", "file.treasure-maps.com", "sab.example"
    ])
    let searchURL = try #require(requests.dropFirst(3).first?.url)
    var search = try #require(URLComponents(url: searchURL, resolvingAgainstBaseURL: false))
    search.percentEncodedQuery = search.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%20")
    let searchItems = try #require(search.queryItems)
    #expect(searchItems.first { $0.name == "q" }?.value == link.title)
    #expect(searchItems.first { $0.name == "apikey" }?.value == apiKey)
    #expect(!searchURL.absoluteString.contains("test-password"))
    #expect(requests.dropFirst(4).first?.url?.absoluteString == downloadURL)
    let last = try #require(requests.last)
    let body = String(decoding: try #require(last.httpBody), as: UTF8.self)
    #expect(body.contains("name=\"mode\"\r\n\r\naddfile\r\n"))
    #expect(body.contains("name=\"cat\"\r\n\r\ntest-category\r\n"))
    #expect(body.contains("name=\"nzbname\"\r\n\r\n\(link.title)\r\n"))
    #expect(body.contains("name=\"password\"\r\n\r\ntest-password\r\n"))
    #expect(body.contains("name=\"priority\"\r\n\r\n-2\r\n"))
    #expect(body.contains(nzb))
    #expect(!body.contains(apiKey))
    #expect(last.url?.query == nil)
}

@Test func newzBayRunsAfterTreasureMapsAndUsesItsOwnKeyForTheNZB() async throws {
    let id = "0123456789abcdef0123456789abcdef"
    let nzb = "<nzb><file/></nzb>"
    let transport = SearchTransport([
        #"{"data":{"content":[]},"error":false}"#, "<html></html>", "<html></html>",
        "<rss><channel></channel></rss>",
        """
        <rss xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/" version="2.0">
          <channel><item><title>Test.Package.S01E07.GERMAN-Team</title>
            <newznab:attr name="guid" value="\(id)"/>
          </item></channel>
        </rss>
        """,
        nzb,
        #"{"status":true,"nzo_ids":["test-job"]}"#
    ])
    let link = try NZBLink("nzblnk:?h=fixture&t=Test+Package+S01E07+GERMAN-Team&p=test-password")
    let treasureMaps = NewznabClient(apiKey: "test-treasure-key", service: .treasureMaps, transport: transport)
    let newzBay = NewznabClient(apiKey: "test-newzbay-key", service: .newzBay, transport: transport)
    let resolver = NZBResolver(transport: transport, newznabClients: [treasureMaps, newzBay])
    let download = try await resolver.resolve(link)
    let file = try #require(await resolver.fetchFile(download))
    try await SABClient(transport: transport).send(file, category: "test-category",
        connection: ServerConnection(address: "https://sab.example/api", apiKey: "test-only-key"),
        title: link.title, password: link.password)

    let requests = await transport.requests()
    #expect(requests.map { $0.url?.host } == [
        "nzbindex.com", "www.nzbking.com", "www.binsearch.info", "treasure-maps.com", "newzbay.cc", "newzbay.cc", "sab.example"
    ])
    for (request, expected) in zip(requests.dropFirst(3), ["test-treasure-key", "test-newzbay-key", "test-newzbay-key"]) {
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(components.queryItems?.first { $0.name == "apikey" }?.value == expected)
    }
    let components = try #require(URLComponents(url: download, resolvingAgainstBaseURL: false))
    #expect(components.queryItems?.first { $0.name == "t" }?.value == "get")
    #expect(components.queryItems?.first { $0.name == "id" }?.value == id)
    let upload = String(decoding: try #require(requests.last?.httpBody), as: UTF8.self)
    #expect(upload.contains(nzb))
    #expect(!upload.contains("test-newzbay-key"))
    #expect(!upload.contains("test-treasure-key"))
}
