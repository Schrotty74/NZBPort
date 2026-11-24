import Foundation
import Testing
@testable import RelayCore

private actor VideothekTransport: HTTPTransport {
    private var responses: [HTTPResult]
    private var requests: [URLRequest] = []

    init(_ bodies: [String]) {
        responses = bodies.map { HTTPResult(data: Data($0.utf8), status: 200) }
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        return responses.isEmpty ? HTTPResult(data: Data(), status: 500) : responses.removeFirst()
    }

    func captured() -> [URLRequest] { requests }
}

private func videothekRSS(guid: String) -> String {
    "<rss><channel><item><title>Title.S01E01-GROUP</title><guid>\(guid)</guid></item></channel></rss>"
}

@Test(arguments: [
    "0123456789abcdef0123456789abcdef01234567",
    "ae5bc13116be4abb855dfdb7dee1739f",
    "ae5bc131-16be-4abb-855d-fdb7dee1739f"
])
func videothekUsesNewznabSearchAndAuthenticatedGet(_ id: String) async throws {
    let secret = "synthetic-videothek-key"
    let nzb = "<nzb xmlns='http://www.newzbin.com/DTD/2003/nzb'><file/></nzb>"
    let transport = VideothekTransport([videothekRSS(guid: id), nzb])
    let client = NewznabClient(apiKey: secret, service: .videothek, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")

    let download = try await client.resolve(link)
    let components = try #require(URLComponents(url: download, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "https")
    #expect(components.host == "videothek.io")
    #expect(components.path == "/api")
    #expect(components.queryItems?.first(where: { $0.name == "t" })?.value == "get")
    #expect(components.queryItems?.first(where: { $0.name == "id" })?.value == id)
    #expect(components.queryItems?.first(where: { $0.name == "apikey" })?.value == secret)
    let file = try #require(try await client.fetchIfApplicable(download))
    #expect(file.data == Data(nzb.utf8))

    let requests = await transport.captured()
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.url?.host == "videothek.io" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "User-Agent") == "NZBPort/0.2.6 (+https://github.com/Schrotty74/NZBPort)" })
    let searchURL = try #require(requests.first?.url)
    let search = try #require(URLComponents(url: searchURL, resolvingAgainstBaseURL: false))
    #expect(search.queryItems?.first(where: { $0.name == "t" })?.value == "search")
    #expect(search.queryItems?.first(where: { $0.name == "q" })?.value == "Title.S01E01-GROUP")
    #expect(search.queryItems?.first(where: { $0.name == "o" })?.value == "xml")
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
}

@Test(arguments: [
    "bad-ae5bc131-16be-4abb-855d-fdb7dee1739f",
    "https://attacker.example/details/ae5bc13116be4abb855dfdb7dee1739f",
    "ae5bc131-16be-4abb-855d-fdb7dee1739g"
])
func videothekRejectsMalformedOrUntrustedIdentifiers(_ id: String) async throws {
    let transport = VideothekTransport([videothekRSS(guid: id)])
    let client = NewznabClient(apiKey: "synthetic", service: .videothek, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
}

@Test func videothekDoesNotFetchCredentialsForOtherHosts() async throws {
    let client = NewznabClient(apiKey: "synthetic", service: .videothek, transport: VideothekTransport([]))
    #expect(try await client.fetchIfApplicable(URL(string: "https://videothek.io.evil/api?t=get&id=ae5bc13116be4abb855dfdb7dee1739f&apikey=synthetic")!) == nil)
}

@Test(arguments: [true, false])
func videothekResolvesTrustedDownloadWithoutGUID(_ enclosure: Bool) async throws {
    let id = "0123456789abcdef0123456789abcdef01234567"
    let address = "https://videothek.io/api?t=get&amp;id=\(id)&amp;apikey=synthetic"
    let download = enclosure
        ? "<enclosure url='\(address)' type='application/x-nzb'/>"
        : "<link>\(address)</link>"
    let rss = "<rss><channel><item><title>Title.S01E01-GROUP</title>\(download)</item></channel></rss>"
    let client = NewznabClient(apiKey: "synthetic", service: .videothek, transport: VideothekTransport([rss]))
    let result = try await client.resolve(NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP"))
    let query = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems
    #expect(query?.first(where: { $0.name == "id" })?.value == id)
}
