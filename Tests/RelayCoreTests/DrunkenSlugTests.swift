import Foundation
import Testing
@testable import RelayCore

private actor DrunkenSlugTestTransport: HTTPTransport {
    private let body: Data
    private var captured: [URLRequest] = []

    init(_ body: String) { self.body = Data(body.utf8) }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        captured.append(request)
        return HTTPResult(data: body, status: 200)
    }

    func requests() -> [URLRequest] { captured }
}

@Test func drunkenSlugSearchUsesNewznabAPIAndRawGUID() async throws {
    let id = "0123456789abcdef0123456789abcdef"
    let body = "<rss><channel><item><title>Title.S01E01-GROUP</title><guid isPermaLink='false'>\(id)</guid></item></channel></rss>"
    let transport = DrunkenSlugTestTransport(body)
    let client = NewznabClient(apiKey: "synthetic-secret", service: .drunkenSlug, transport: transport)

    let result = try await client.resolve(NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP"))
    #expect(result.absoluteString == "https://drunkenslug.com/api?t=get&id=\(id)&apikey=synthetic-secret")

    let search = try #require(await transport.requests().first)
    let components = try #require(search.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
    #expect(components.host == "drunkenslug.com")
    #expect(components.path == "/api")
    #expect(components.queryItems?.first(where: { $0.name == "t" })?.value == "search")
    #expect(components.queryItems?.first(where: { $0.name == "q" })?.value == "Title.S01E01-GROUP")
    #expect(components.queryItems?.first(where: { $0.name == "o" })?.value == "xml")
    #expect(components.queryItems?.first(where: { $0.name == "apikey" })?.value == "synthetic-secret")
}

@Test func drunkenSlugAcceptsIDAttributeAndAPIURLGUID() async throws {
    let id = "fedcba9876543210fedcba9876543210"
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    let fromAttribute = NewznabClient(apiKey: "synthetic", service: .drunkenSlug,
        transport: DrunkenSlugTestTransport("<rss><channel><item><title>Title.S01E01-GROUP</title><guid id='\(id)'/></item></channel></rss>"))
    #expect(try await fromAttribute.resolve(link).query?.contains("id=\(id)") == true)

    let fromURL = NewznabClient(apiKey: "synthetic", service: .drunkenSlug,
        transport: DrunkenSlugTestTransport("<rss><channel><item><title>Title.S01E01-GROUP</title><guid>https://drunkenslug.com/api?id=\(id)</guid></item></channel></rss>"))
    #expect(try await fromURL.resolve(link).query?.contains("id=\(id)") == true)

    let fromDetails = NewznabClient(apiKey: "synthetic", service: .drunkenSlug,
        transport: DrunkenSlugTestTransport("<rss><channel><item><title>Title.S01E01-GROUP</title><guid>https://drunkenslug.com/details/\(id)</guid></item></channel></rss>"))
    #expect(try await fromDetails.resolve(link).query?.contains("id=\(id)") == true)
}

@Test func drunkenSlugFetchesAuthenticatedNZBBytesLocally() async throws {
    let secret = "synthetic-secret"
    let transport = DrunkenSlugTestTransport("<nzb><file/></nzb>")
    let client = NewznabClient(apiKey: secret, service: .drunkenSlug, transport: transport)
    let url = URL(string: "https://drunkenslug.com/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic-secret")!

    let file = try #require(try await client.fetchIfApplicable(url))
    #expect(file.data == Data("<nzb><file/></nzb>".utf8))
    #expect(file.title == "0123456789abcdef0123456789abcdef")
    let request = try #require(await transport.requests().last)
    #expect(request.url == url)
    #expect(!request.url!.host!.contains(secret))
    await #expect(throws: (any Error).self) {
        try await client.fetchIfApplicable(URL(string: "https://drunkenslug.com/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=wrong")!)
    }
    #expect(try await client.fetchIfApplicable(URL(string: "https://elsewhere.invalid/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic-secret")!) == nil)
}

@Test(arguments: [
    "https://drunkenslug.com.evil/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic",
    "http://drunkenslug.com/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic",
    "https://user:password@drunkenslug.com/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic",
    "https://drunkenslug.com:444/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic",
    "https://drunkenslug.com/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=wrong",
    "https://drunkenslug.com/api?t=get&id=0123456789abcdef0123456789abcdef&apikey=synthetic&apikey=synthetic"
])
func drunkenSlugRejectsUnsafeAuthenticatedDownloadURLs(_ raw: String) async throws {
    let client = NewznabClient(apiKey: "synthetic", service: .drunkenSlug,
        transport: DrunkenSlugTestTransport("<nzb><file/></nzb>"))
    if URL(string: raw)?.host != "drunkenslug.com" {
        #expect(try await client.fetchIfApplicable(URL(string: raw)!) == nil)
    } else {
        await #expect(throws: (any Error).self) { try await client.fetchIfApplicable(URL(string: raw)!) }
    }
}
