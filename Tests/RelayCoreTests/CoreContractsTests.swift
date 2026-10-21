import Foundation
import Testing
@testable import RelayCore

@Test func linkReadsSpecificationFieldsAndRepeatedGroups() throws {
    let link = try NZBLink("nzblnk:?t=Meine+Musik%2B&h=a%26b&p=x%2By&g=alt.one&g=alt.two")
    #expect(link.title == "Meine Musik+")
    #expect(link.header == "a&b")
    #expect(link.password == "x+y")
    #expect(link.groups == ["alt.one", "alt.two"])
}

@Test(arguments: ["https://host/?h=x", "nzblnk:?h=", "nzblnk:?t=x", "nzblnk:?h=a&h=b", "nzblnk://host/?h=a"])
func invalidOrConflictingLinksAreRejected(_ value: String) {
    #expect(throws: (any Error).self) { try NZBLink(value) }
}

@Test func legacyLinksWithoutTitleStillWork() throws {
    #expect(try NZBLink("nzblnk://?h=legacy").title == "legacy")
}

@Test func localCategoryChoicesSurviveServerRefreshes() throws {
    var choices = CategoryPreferences()
    choices.setVisible(false, category: "Musik")
    let persisted = try JSONEncoder().encode(choices)
    var restored = try JSONDecoder().decode(CategoryPreferences.self, from: persisted)
    #expect(restored.visible(in: ["*", "musik", "Filme"]) == ["*", "Filme"])
    #expect(restored.visible(in: ["Musik", "Neu", "Filme"]) == ["Neu", "Filme"])
    #expect(restored.visible(in: ["Neu"]) == ["Neu"])
    #expect(restored.hidden == ["Musik"])
    restored.setVisible(true, category: "MUSIK")
    #expect(restored.visible(in: ["Musik", "Neu"]) == ["Musik", "Neu"])
}

@Test(arguments: [
    ("http://localhost:8080", "http://localhost:8080/api"),
    ("https://host/sab/", "https://host/sab/api"),
    ("https://host/sab/api/", "https://host/sab/api")
])
func sabEndpointRetainsReverseProxyPrefix(_ source: String, _ destination: String) throws {
    #expect(try ServerConnection(address: source, apiKey: " key ").endpoint.absoluteString == destination)
}

@Test(arguments: ["file:///api", "https://user:pass@host/", "https://host/?apikey=x"])
func sabAddressCannotIncludeCredentialsOrParameters(_ value: String) {
    #expect(throws: (any Error).self) { try ServerConnection(address: value, apiKey: "key") }
}

private actor IndexTransport: HTTPTransport {
    let result: HTTPResult
    var requests: [URLRequest] = []
    init(_ json: String, status: Int = 200) {
        result = HTTPResult(data: Data(json.utf8), status: status)
    }
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        return result
    }
    func captured() -> [URLRequest] { requests }
}

@Test func publicIndexSearchNeedsNoKeyAndUsesDocumentedDownload() async throws {
    let transport = IndexTransport(#"{"data":{"content":[{"id":"abc-123"}]},"error":false}"#)
    let link = try NZBLink("nzblnk:?h=unique%26header&t=Title&g=alt.example")
    let download = try await NZBIndexClient(transport: transport).resolve(link)
    #expect(download.absoluteString == "https://nzbindex.com/api/download/abc-123.nzb")
    let request = try #require(await transport.captured().first)
    let url = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
    #expect(url.host == "nzbindex.com")
    #expect(url.path == "/api/search")
    #expect(url.queryItems?.first { $0.name == "q" }?.value == "unique&header")
    #expect(url.queryItems?.first { $0.name == "groups" }?.value == "alt.example")
    #expect(url.queryItems?.contains { $0.name == "key" || $0.name == "apikey" } == false)
}

@Test func abbreviatedUsenetGroupsAreExpandedForIndexSearch() async throws {
    let transport = IndexTransport(#"{"data":{"content":[{"id":"test-collection"}]},"error":false}"#)
    let link = try NZBLink("nzblnk:?h=synthetic-header&t=Package&g=a.b.example&g=A.B.other&g=alt.binaries.full")
    _ = try await NZBIndexClient(transport: transport).resolve(link)
    let request = try #require(await transport.captured().first)
    let query = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
    #expect(query.queryItems?.filter { $0.name == "groups" }.compactMap(\.value)
        == ["alt.binaries.example", "alt.binaries.other", "alt.binaries.full"])
}

@Test(arguments: [
    #"{"data":{"content":[]},"error":false}"#,
    #"{"data":{"content":[{"id":"a"},{"id":"b"}]},"error":false}"#,
    #"{"data":{"content":[{"id":"../escape"}]},"error":false}"#,
    #"{"error":true,"errorMessage":"failure"}"#,
    "<html>Temporarily unavailable</html>"
])
func indexNeverTreatsMissingAmbiguousOrInvalidResultAsDownload(_ json: String) async throws {
    let transport = IndexTransport(json)
    await #expect(throws: (any Error).self) {
        try await NZBIndexClient(transport: transport).resolve(NZBLink("nzblnk:?h=unique"))
    }
    #expect(await transport.captured().count == 1)
}

@Test func indexDoesNotFallBackToHTMLWhenHTTPFails() async throws {
    let transport = IndexTransport("{}", status: 429)
    await #expect(throws: (any Error).self) {
        try await NZBIndexClient(transport: transport).resolve(NZBLink("nzblnk:?h=unique"))
    }
    #expect(await transport.captured().count == 1)
}
