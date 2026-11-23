import Foundation
import Testing
@testable import RelayCore

private actor CategoryDeletionTransport: HTTPTransport {
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

private func deletionHTTP(_ body: String, status: Int = 200) -> Result<HTTPResult, Error> {
    .success(HTTPResult(data: Data(body.utf8), status: status))
}

private let deletionCategoryConfig = #"{"config":{"categories":[{"name":"*"},{"name":"Movies"},{"name":"tv"}]}}"#

private func deletionFormValues(_ request: URLRequest) -> [String: String] {
    guard let body = request.httpBody,
          let components = URLComponents(string: "https://example.invalid/?" + String(decoding: body, as: UTF8.self)) else { return [:] }
    return Dictionary(components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { first, _ in first })
}

private func deletionConnection() throws -> ServerConnection {
    try ServerConnection(address: "https://sab.example:8080/sab", apiKey: "private-api-key")
}

@Test(arguments: ["", "  \n", "*"])
func deleteCategoryRejectsEmptyOrDefaultWithoutNetwork(_ name: String) async throws {
    let transport = CategoryDeletionTransport([])

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).deleteCategory(name, connection: deletionConnection())
    }
    #expect(await transport.requests().isEmpty)
}

@Test func deleteCategoryRequiresExistingNameBeforeWriting() async throws {
    let transport = CategoryDeletionTransport([deletionHTTP(deletionCategoryConfig)])

    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).deleteCategory("Music", connection: deletionConnection())
    }
    #expect(await transport.requests().count == 1)
}

@Test func deleteCategoryUsesCanonicalExistingNameAndConfirmsRemoval() async throws {
    let updated = #"{"config":{"categories":[{"name":"*"},{"name":"tv"}]}}"#
    let transport = CategoryDeletionTransport([
        deletionHTTP(deletionCategoryConfig),
        deletionHTTP(#"{"status":true}"#),
        deletionHTTP(updated)
    ])

    try await SABClient(transport: transport).deleteCategory(" movies ", connection: deletionConnection())

    let requests = await transport.requests()
    #expect(requests.count == 3)
    #expect(requests.allSatisfy { $0.httpMethod == "POST" && $0.url?.query == nil })
    let read = deletionFormValues(requests[0])
    #expect(read["mode"] == "get_config")
    #expect(read["section"] == "categories")
    #expect(read["apikey"] == "private-api-key")
    let write = deletionFormValues(requests[1])
    #expect(write["mode"] == "del_config")
    #expect(write["section"] == "categories")
    #expect(write["keyword"] == "Movies")
    #expect(write["name"] == nil)
    #expect(write["apikey"] == "private-api-key")
    #expect(deletionFormValues(requests[2])["mode"] == "get_config")
}

@Test func deleteCategoryReportsUnknownStatusWithoutRetryAfterWriteFailure() async throws {
    let transport = CategoryDeletionTransport([
        deletionHTTP(deletionCategoryConfig),
        .failure(URLError(.timedOut))
    ])

    do {
        try await SABClient(transport: transport).deleteCategory("Movies", connection: deletionConnection())
        Issue.record("A timed-out category deletion must not be reported as confirmed.")
    } catch let error as RelayError {
        #expect(error.localizedDescription == Localization.string("The connection to SABnzbd was interrupted while deleting the category. Its status is unknown; refresh the category list before trying again.", table: "Errors"))
    }
    #expect(await transport.requests().count == 2)
}

@Test func deleteCategoryPropagatesCancellationWithoutRetry() async throws {
    let transport = CategoryDeletionTransport([
        deletionHTTP(deletionCategoryConfig), .failure(URLError(.cancelled))
    ])

    await #expect(throws: CancellationError.self) {
        try await SABClient(transport: transport).deleteCategory("Movies", connection: deletionConnection())
    }
    #expect(await transport.requests().count == 2)
}

@Test func deleteCategoryTreatsMalformedWriteResponseAsUnknown() async throws {
    let transport = CategoryDeletionTransport([
        deletionHTTP(deletionCategoryConfig), deletionHTTP(#"{"status":"yes"}"#)
    ])

    do {
        try await SABClient(transport: transport).deleteCategory("Movies", connection: deletionConnection())
        Issue.record("A malformed deletion response must not be reported as confirmed.")
    } catch let error as RelayError {
        #expect(error.localizedDescription == Localization.string("The connection to SABnzbd was interrupted while deleting the category. Its status is unknown; refresh the category list before trying again.", table: "Errors"))
    }
    #expect(await transport.requests().count == 2)
}

@Test func deleteCategoryMapsPostWriteReadFailureToUnknown() async throws {
    let transport = CategoryDeletionTransport([
        deletionHTTP(deletionCategoryConfig), deletionHTTP(#"{"status":true}"#),
        .success(HTTPResult(data: Data(), status: 503))
    ])

    do {
        try await SABClient(transport: transport).deleteCategory("Movies", connection: deletionConnection())
        Issue.record("A failed verification read must not be reported as confirmed.")
    } catch let error as RelayError {
        #expect(error.localizedDescription == Localization.string("The connection to SABnzbd was interrupted while deleting the category. Its status is unknown; refresh the category list before trying again.", table: "Errors"))
    }
    #expect(await transport.requests().count == 3)
}

@Test func deleteCategoryRejectsSuccessStatusWhenCategoryStillExists() async throws {
    let transport = CategoryDeletionTransport([
        deletionHTTP(deletionCategoryConfig), deletionHTTP(#"{"status":true}"#), deletionHTTP(deletionCategoryConfig)
    ])
    await #expect(throws: (any Error).self) {
        try await SABClient(transport: transport).deleteCategory("Movies", connection: deletionConnection())
    }
    #expect(await transport.requests().count == 3)
}
