import Foundation
import Testing
@testable import RelayCore

private actor SABTestTransport: HTTPTransport {
    private var result: Result<HTTPResult, Error>
    private var capturedRequest: URLRequest?

    init(_ result: Result<HTTPResult, Error>) {
        self.result = result
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        capturedRequest = request
        return try result.get()
    }

    func request() -> URLRequest? { capturedRequest }
}

private func sabResponse(_ body: String, status: Int = 200) -> HTTPResult {
    HTTPResult(data: Data(body.utf8), status: status)
}

private func testConnection() throws -> ServerConnection {
    try ServerConnection(address: "https://sab.example:8080/sab", apiKey: "private-api-key")
}

@Test func categoriesUsesDocumentedJSONAndAllowsEmptyList() async throws {
    let transport = SABTestTransport(.success(sabResponse(#"{"categories":[]}"#)))
    let categories = try await SABClient(transport: transport).categories(testConnection())

    #expect(categories.isEmpty)
    let request = try #require(await transport.request())
    #expect(request.httpMethod == "POST")
    #expect(request.url?.query == nil)
    let body = try #require(request.httpBody)
    let formBody = String(decoding: body, as: UTF8.self).replacingOccurrences(of: "+", with: "%20")
    let fields = URLComponents(string: "https://example.invalid/?" + formBody)?.queryItems ?? []
    #expect(fields.first { $0.name == "mode" }?.value == "get_cats")
    #expect(fields.first { $0.name == "output" }?.value == "json")
    #expect(fields.first { $0.name == "apikey" }?.value == "private-api-key")
    #expect(request.timeoutInterval == 25)
}

@Test func categoriesDeduplicateWhilePreservingFirstOccurrence() async throws {
    let transport = SABTestTransport(.success(sabResponse(#"{"categories":["*","Series","*","Series","Movies"]}"#)))
    let categories = try await SABClient(transport: transport).categories(testConnection())

    #expect(categories == ["*", "Series", "Movies"])
}

@Test func categoriesSurfacesSABnzbdAPIError() async throws {
    let transport = SABTestTransport(.success(sabResponse(#"{"error":"API Key Incorrect"}"#)))

    do {
        _ = try await SABClient(transport: transport).categories(testConnection())
        Issue.record("An API error must not be treated as an empty category list.")
    } catch let error as RelayError {
        #expect(error.localizedDescription.contains("API Key Incorrect"))
    }
}

@Test func sendPostsDocumentedAddURLFieldsAndConfirmsQueueID() async throws {
    let transport = SABTestTransport(.success(sabResponse(#"{"status":true,"nzo_ids":["SABnzbd_nzo_123"]}"#)))
    let client = SABClient(transport: transport)
    let link = try NZBLink("nzblnk:?h=header&t=Episode%20%2B%20Title&p=pass%26word")
    let download = try #require(URL(string: "https://indexer.example/get?n=1&x=2"))

    try await client.send(link, download: download, category: "Series & TV", connection: testConnection())

    let request = try #require(await transport.request())
    #expect(request.httpMethod == "POST")
    #expect(request.url?.query == nil)
    let body = try #require(request.httpBody)
    let formBody = String(decoding: body, as: UTF8.self).replacingOccurrences(of: "+", with: "%20")
    let fields = URLComponents(string: "https://example.invalid/?" + formBody)?.queryItems ?? []
    func value(_ name: String) -> String? { fields.first { $0.name == name }?.value }
    #expect(value("mode") == "addurl")
    #expect(value("name") == download.absoluteString)
    #expect(value("nzbname") == "Episode + Title")
    #expect(value("password") == "pass&word")
    #expect(value("cat") == "Series & TV")
    #expect(value("apikey") == "private-api-key")
}

@Test(arguments: [
    #"{"status":false,"nzo_ids":["id"]}"#,
    #"{"status":true,"nzo_ids":[]}"#,
    #"{"error":"API Key Incorrect"}"#
])
func sendRejectsUnconfirmedOrFailedAPIResponses(_ body: String) async throws {
    let transport = SABTestTransport(.success(sabResponse(body)))
    let client = SABClient(transport: transport)
    let link = try NZBLink("nzblnk:?h=header")
    let download = try #require(URL(string: "https://indexer.example/file.nzb"))

    await #expect(throws: (any Error).self) {
        try await client.send(link, download: download, category: "*", connection: testConnection())
    }
}

@Test func sendRejectsHTTPFailureEvenWithSuccessBody() async throws {
    let transport = SABTestTransport(.success(sabResponse(#"{"status":true,"nzo_ids":["id"]}"#, status: 503)))
    let link = try NZBLink("nzblnk:?h=header")
    let download = try #require(URL(string: "https://indexer.example/file.nzb"))

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).send(link, download: download, category: "*", connection: testConnection())
    }
}

@Test func sendReportsTimeoutAsUnknownQueueState() async throws {
    let transport = SABTestTransport(.failure(URLError(.timedOut)))
    let link = try NZBLink("nzblnk:?h=header")
    let download = try #require(URL(string: "https://indexer.example/file.nzb"))

    do {
        try await SABClient(transport: transport).send(link, download: download, category: "*", connection: testConnection())
        Issue.record("A timed-out submission must not be reported as successful.")
    } catch let error as RelayError {
        #expect(error.localizedDescription.contains("Downloadstatus ist unklar"))
        #expect(error.localizedDescription.contains("Warteschlange prüfen"))
    }
}

@Test func cancellationIsPropagated() async throws {
    let transport = SABTestTransport(.failure(URLError(.cancelled)))
    let link = try NZBLink("nzblnk:?h=header")
    let download = try #require(URL(string: "https://indexer.example/file.nzb"))

    await #expect(throws: CancellationError.self) {
        try await SABClient(transport: transport).send(link, download: download, category: "*", connection: testConnection())
    }
}
