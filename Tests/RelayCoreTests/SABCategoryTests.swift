import Foundation
import Testing
@testable import RelayCore

private actor CategoryTransport: HTTPTransport {
    private var responses: [Result<HTTPResult, Error>]
    private var captured: [URLRequest] = []

    init(_ responses: [Result<HTTPResult, Error>]) { self.responses = responses }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        captured.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return try responses.removeFirst().get()
    }

    func requests() -> [URLRequest] { captured }
}

private func categoryHTTP(_ body: String, status: Int = 200) -> Result<HTTPResult, Error> {
    .success(HTTPResult(data: Data(body.utf8), status: status))
}

private let categoryList = #"{"config":{"categories":[{"name":"*"},{"name":"movies","dir":"","script":"Default","priority":-100}]}}"#

private func formValues(_ request: URLRequest) -> [String: String] {
    guard let body = request.httpBody,
          let components = URLComponents(string: "https://example.invalid/?" + String(decoding: body, as: UTF8.self)) else { return [:] }
    return Dictionary(components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { first, _ in first })
}

private func categoryConnection() throws -> ServerConnection {
    try ServerConnection(address: "https://sab.example:8080/sab", apiKey: "private-api-key")
}

@Test func createCategoryChecksConfigurationThenUsesSABDefaults() async throws {
    let transport = CategoryTransport([
        categoryHTTP(categoryList),
        categoryHTTP(#"{"config":{"categories":[{"name":"*"},{"name":"movies"},{"name":"documentaries"}]}}"#)
    ])

    try await SABClient(transport: transport).createCategory(" Documentaries ", connection: categoryConnection())

    let requests = await transport.requests()
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.httpMethod == "POST" && $0.url?.query == nil })
    let read = formValues(requests[0])
    #expect(read["mode"] == "get_config")
    #expect(read["section"] == "categories")
    #expect(read["apikey"] == "private-api-key")
    let write = formValues(requests[1])
    #expect(write["mode"] == "set_config")
    #expect(write["section"] == "categories")
    #expect(write["name"] == "Documentaries")
    #expect(write["output"] == "json")
    #expect(write["apikey"] == "private-api-key")
    #expect(write["dir"] == nil)
    #expect(write["script"] == nil)
    #expect(write["priority"] == nil)
}

@Test(arguments: ["movies", "MOVIES", " Movies "])
func createCategoryRefusesExistingNameWithoutWriting(_ name: String) async throws {
    let transport = CategoryTransport([categoryHTTP(categoryList)])

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).createCategory(name, connection: categoryConnection())
    }
    #expect(await transport.requests().count == 1)
}

@Test(arguments: ["", "  \n", "*", "TV*", "Bad\nName"])
func createCategoryRejectsInvalidNameWithoutNetwork(_ name: String) async throws {
    let transport = CategoryTransport([])

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).createCategory(name, connection: categoryConnection())
    }
    #expect(await transport.requests().isEmpty)
}

@Test func createCategoryFailsClosedOnMalformedConfiguration() async throws {
    let transport = CategoryTransport([categoryHTTP(#"{"config":{"categories":[]}}"#)])

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).createCategory("Archive", connection: categoryConnection())
    }
    #expect(await transport.requests().count == 1)
}

@Test func createCategoryReportsUnknownWriteStatusWithoutRetry() async throws {
    let transport = CategoryTransport([categoryHTTP(categoryList), .failure(URLError(.timedOut))])

    do {
        try await SABClient(transport: transport).createCategory("Archive", connection: categoryConnection())
        Issue.record("A timed-out write must not be reported as confirmed.")
    } catch is RelayError {
        // Any failure after the write begins is surfaced as an unknown create result.
    }
    #expect(await transport.requests().count == 2)
}

@Test func createCategoryRejectsUnconfirmedWriteResponse() async throws {
    let transport = CategoryTransport([categoryHTTP(categoryList), categoryHTTP(#"{"status":true}"#)])

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).createCategory("Archive", connection: categoryConnection())
    }
    #expect(await transport.requests().count == 2)
}
