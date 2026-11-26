import Foundation
import Testing
@testable import RelayCore

private actor NZBFinderTransport: HTTPTransport {
    private var responses: [HTTPResult]
    private var requests: [URLRequest] = []

    init(_ bodies: [String], status: Int = 200) {
        responses = bodies.map { HTTPResult(data: Data($0.utf8), status: status) }
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        return responses.isEmpty ? HTTPResult(data: Data(), status: 500) : responses.removeFirst()
    }

    func captured() -> [URLRequest] { requests }
}

private func nzbFinderRSS(guid: String) -> String {
    "<rss><channel><item><title>Title.S01E01-GROUP</title>\(guid)</item></channel></rss>"
}

@Test(arguments: [
    "<guid isPermaLink='false'>ae5bc131-16be-4abb-855d-fdb7dee1739f</guid>",
    "<guid>https://nzbfinder.ws/details/ae5bc131-16be-4abb-855d-fdb7dee1739f</guid>",
    "<guid>https://nzbfinder.ws/api?t=get&amp;id=ae5bc131-16be-4abb-855d-fdb7dee1739f</guid>"
])
func nzbFinderResolvesUUIDsFromRawDetailsAndAPIGUIDs(_ guid: String) async throws {
    let transport = NZBFinderTransport([nzbFinderRSS(guid: guid)])
    let client = NewznabClient(apiKey: "synthetic", service: .nzbFinder, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")

    let download = try await client.resolve(link)
    let components = try #require(URLComponents(url: download, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "https")
    #expect(components.host == "nzbfinder.ws")
    #expect(components.path == "/api")
    #expect(components.queryItems?.first(where: { $0.name == "t" })?.value == "get")
    #expect(components.queryItems?.first(where: { $0.name == "id" })?.value == "ae5bc131-16be-4abb-855d-fdb7dee1739f")
    #expect(components.queryItems?.first(where: { $0.name == "apikey" })?.value == "synthetic")
    let search = try #require(await transport.captured().first)
    #expect(search.value(forHTTPHeaderField: "User-Agent") == "NZBPort/0.2.8 (+https://github.com/Schrotty74/NZBPort)")
    #expect(URLComponents(url: try #require(search.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "o" })?.value == "xml")
}

@Test(arguments: ["ae5bc131-16be-4abb-855d-fdb7dee1739f", "0123456789abcdef0123456789abcdef01234567"])
func nzbFinderFetchesValidatedNZBWithUserAgentAndOnlyContactsProviderHost(_ id: String) async throws {
    let nzb = "<nzb xmlns='http://www.newzbin.com/DTD/2003/nzb'><file/></nzb>"
    let transport = NZBFinderTransport([nzbFinderRSS(guid: "<guid>\(id)</guid>"), nzb])
    let client = NewznabClient(apiKey: "synthetic-secret", service: .nzbFinder, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    let url = try await client.resolve(link)
    let file = try #require(try await client.fetchIfApplicable(url))
    #expect(file.data == Data(nzb.utf8))

    let requests = await transport.captured()
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.url?.host == "nzbfinder.ws" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "User-Agent") == "NZBPort/0.2.8 (+https://github.com/Schrotty74/NZBPort)" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    #expect(requests[1].url?.query?.contains("synthetic-secret") == true)
    #expect(try await client.fetchIfApplicable(URL(string: "https://elsewhere.invalid/api?t=get&id=\(id)&apikey=synthetic-secret")!) == nil)
    #expect((await transport.captured()).count == 2)
}

@Test(arguments: [
    "bad-ae5bc131-16be-4abb-855d-fdb7dee1739f",
    "ae5bc131-16be-4abb-855d-fdb7dee1739",
    "ae5bc131-16be-4abb-855d-fdb7dee1739g",
    "https://attacker.example/details/ae5bc131-16be-4abb-855d-fdb7dee1739f",
    "https://nzbfinder.ws.evil/details/ae5bc131-16be-4abb-855d-fdb7dee1739f"
])
func nzbFinderRejectsMalformedOrUntrustedIdentifiers(_ guid: String) async throws {
    let transport = NZBFinderTransport([nzbFinderRSS(guid: "<guid>\(guid)</guid>")])
    let client = NewznabClient(apiKey: "synthetic", service: .nzbFinder, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
}

@Test func nzbFinderRejectsUnsafeAuthenticatedDownloadURLs() async throws {
    let uuid = "ae5bc131-16be-4abb-855d-fdb7dee1739f"
    let client = NewznabClient(apiKey: "synthetic", service: .nzbFinder, transport: NZBFinderTransport([]))
    #expect(try await client.fetchIfApplicable(URL(string: "https://nzbfinder.ws.evil/api?t=get&id=\(uuid)&apikey=synthetic")!) == nil)
    for raw in [
        "http://nzbfinder.ws/api?t=get&id=\(uuid)&apikey=synthetic",
        "https://user@nzbfinder.ws/api?t=get&id=\(uuid)&apikey=synthetic",
        "https://nzbfinder.ws:444/api?t=get&id=\(uuid)&apikey=synthetic",
        "https://nzbfinder.ws/api?t=get&id=\(uuid)&apikey=synthetic&extra=value",
        "https://nzbfinder.ws/api?t=get&id=bad&apikey=synthetic"
    ] {
        await #expect(throws: (any Error).self) {
            try await client.fetchIfApplicable(URL(string: raw)!)
        }
    }
}


@Test(arguments: [NewznabClient.Service.newzBay, .ninjaCentral, .drunkenSlug])
func nonFinderServicesRejectDashedUUIDIdentifiers(_ service: NewznabClient.Service) async throws {
    let guid = "ae5bc131-16be-4abb-855d-fdb7dee1739f"
    let client = NewznabClient(apiKey: "synthetic", service: service,
        transport: NZBFinderTransport([nzbFinderRSS(guid: "<guid>\(guid)</guid>")]))
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
}


@Test func nzbFinderSurfacesPremiumMembershipRequirementFromUnauthorizedXML() async throws {
    let secret = "synthetic-secret"
    let response = "<error code='102' description='premium membership required; https://nzbfinder.ws/premium; key=\(secret)'/>"
    let transport = NZBFinderTransport([response], status: 401)
    let client = NewznabClient(apiKey: secret, service: .nzbFinder, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")

    do {
        _ = try await client.resolve(link)
        Issue.record("NZBFinder API permission failure must be surfaced.")
    } catch {
        #expect(error.localizedDescription.lowercased().contains("premium"))
        #expect(!error.localizedDescription.contains("nzbfinder.ws"))
        #expect(!error.localizedDescription.contains(secret))
    }
}
