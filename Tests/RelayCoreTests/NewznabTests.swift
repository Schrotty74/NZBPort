import Foundation
import Testing
@testable import RelayCore

private actor NewznabTestTransport: HTTPTransport {
    private let result: HTTPResult
    private var captured: URLRequest?

    init(_ body: String, status: Int = 200) {
        result = HTTPResult(data: Data(body.utf8), status: status)
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        captured = request
        return result
    }

    func request() -> URLRequest? { captured }
}

private func rssItem(_ title: String, enclosure: String = "https://file.treasure-maps.com/getnzb/0123456789abcdef0123456789abcdef?r=0123456789abcdef0123456789abcdef") -> String {
    """
    <item><title>\(title)</title><guid>https://treasure-maps.com/details/0123456789abcdef0123456789abcdef</guid><enclosure url='\(enclosure)' type='application/x-nzb'/></item>
    """
}

private func rss(_ items: String) -> String {
    "<rss xmlns:newznab='http://www.newznab.com/DTD/2010/feeds/attributes/'><channel><newznab:response offset='0' total='1'/>\(items)</channel></rss>"
}

@Test func searchEncodesFullTitleAndReturnsSignedDownloadURL() async throws {
    let title = "S.W.A.T.Exiles.S01E07.GERMAN.DL.1080P.WEB.H264-WAYNE + WEB+DL"
    let transport = NewznabTestTransport(rss(rssItem(title)))
    let client = NewznabClient(apiKey: "synthetic-api-key", service: .treasureMaps, transport: transport)
    let link = try NZBLink("nzblnk:?h=search-id&t=S.W.A.T.Exiles.S01E07.GERMAN.DL.1080P.WEB.H264-WAYNE%20%2B%20WEB%2BDL")
    let result = try await client.resolve(link)

    #expect(result.host == "file.treasure-maps.com")
    #expect(URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "r" }) == true)
    let request = try #require(await transport.request())
    var components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
    let encoded = try #require(components.percentEncodedQuery)
    #expect(encoded.contains("%2B"))
    components.percentEncodedQuery = encoded.replacingOccurrences(of: "+", with: "%20")
    #expect(components.queryItems?.first(where: { $0.name == "q" })?.value == link.title)
    #expect(components.queryItems?.first(where: { $0.name == "apikey" })?.value == "synthetic-api-key")
}

@Test func newzBayBuildsDownloadFromTrustedGUIDAttribute() async throws {
    let id = "0123456789abcdef0123456789abcdef"
    let body = "<rss><channel><item><title>Title.S01E01-GROUP</title><guid id='\(id)'/></item></channel></rss>"
    let transport = NewznabTestTransport(body)
    let client = NewznabClient(apiKey: "synthetic", service: .newzBay, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    let download = try await client.resolve(link)

    #expect(download.absoluteString == "https://newzbay.cc/api?t=get&id=\(id)&apikey=synthetic")
}

@Test func newzBayAcceptsRawGUIDElement() async throws {
    let id = "0123456789abcdef0123456789abcdef"
    let body = "<rss><channel><item><title>Title.S01E01-GROUP</title><guid isPermaLink='false'>\(id)</guid></item></channel></rss>"
    let client = NewznabClient(apiKey: "synthetic", service: .newzBay, transport: NewznabTestTransport(body))
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    #expect(try await client.resolve(link).query?.contains("t=get") == true)
}

@Test func reportsRateLimitSeparatelyFromXMLAPIError() async throws {
    let client = NewznabClient(apiKey: "synthetic", service: .newzBay, transport: NewznabTestTransport("<error code='500'/>", status: 429))
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    do {
        _ = try await client.resolve(link)
        Issue.record("A rate limit response must fail the search.")
    } catch {
        let expected = RelayError.message("The search service rate limit was reached. Wait a while, then try again.")
        #expect(error.localizedDescription == expected.localizedDescription)
    }
}

@Test func canonicalizesCommonSeparatorsButPreservesTitleContent() async throws {
    let transport = NewznabTestTransport(rss(rssItem("S.W.A.T.Exiles.S01E07.GERMAN.DL.1080P.WEB.H264-WAYNE")))
    let client = NewznabClient(apiKey: "synthetic", service: .treasureMaps, transport: transport)
    let link = try NZBLink("nzblnk:?h=identifier&t=s_w_a_t%20exiles%20s01e07%20german%20dl%201080p%20web%20h264-wayne")
    let result = try await client.resolve(link)
    #expect(result.path.hasPrefix("/getnzb/"))
}

@Test func rejectsAmbiguousExactMatches() async throws {
    let title = "Title.S01E01-GROUP"
    let body = rss(rssItem(title) + rssItem("title_s01e01-group"))
    let client = NewznabClient(apiKey: "synthetic", service: .treasureMaps, transport: NewznabTestTransport(body))
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
}

@Test(arguments: [
    "https://attacker.example/getnzb/0123456789abcdef0123456789abcdef?r=x",
    "http://file.treasure-maps.com/getnzb/0123456789abcdef0123456789abcdef?r=x",
    "https://file.treasure-maps.com.evil/getnzb/0123456789abcdef0123456789abcdef?r=x",
    "https://file.treasure-maps.com/getnzb/../../etc/passwd?r=x",
    "https://file.treasure-maps.com/getnzb/0123456789abcdef0123456789abcdef?apikey=synthetic&r=x"
])
func rejectsUnsafeEnclosureURLs(_ enclosure: String) async throws {
    let body = rss(rssItem("Title.S01E01-GROUP", enclosure: enclosure))
    let client = NewznabClient(apiKey: "synthetic", service: .treasureMaps, transport: NewznabTestTransport(body))
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
}

@Test func reportsAuthenticationErrorWithoutLeakingProviderBodyOrKey() async throws {
    let secret = "synthetic-api-key"
    let transport = NewznabTestTransport("<error code='100' description='provider echoed \(secret)'/>")
    let client = NewznabClient(apiKey: secret, service: .treasureMaps, transport: transport)
    let link = try NZBLink("nzblnk:?h=id&t=Title.S01E01-GROUP")
    do {
        _ = try await client.resolve(link)
        Issue.record("An API authentication error must fail the search.")
    } catch {
        #expect(!error.localizedDescription.contains(secret))
        #expect(!error.localizedDescription.contains("provider echoed"))
    }
}

@Test func titleFallbackSkipsRequestWhenTitleEqualsHeader() async throws {
    let transport = NewznabTestTransport(rss(""))
    let client = NewznabClient(apiKey: "synthetic", service: .treasureMaps, transport: transport)
    let link = try NZBLink("nzblnk:?h=identifier")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
    #expect(await transport.request() == nil)
}

@Test func refusesExternalEntities() async throws {
    let body = """
    <!DOCTYPE rss [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]>
    <rss><channel><item><title>&xxe;</title><enclosure url='https://file.treasure-maps.com/getnzb/0123456789abcdef0123456789abcdef?r=x'/></item></channel></rss>
    """
    let client = NewznabClient(apiKey: "synthetic", service: .treasureMaps, transport: NewznabTestTransport(body))
    let link = try NZBLink("nzblnk:?h=id&t=Title")
    await #expect(throws: (any Error).self) { try await client.resolve(link) }
}
