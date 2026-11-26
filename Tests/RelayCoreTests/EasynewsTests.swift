import Foundation
import Testing
@testable import RelayCore

private actor EasynewsTestTransport: HTTPTransport {
    private var replies: [HTTPResult]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [(Int, String)]) {
        self.replies = replies.map { HTTPResult(data: Data($0.1.utf8), status: $0.0) }
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        return replies.removeFirst()
    }
}

private let searchResponse = """
    {"data":[{"0":"other","19":""},{"0":"fixture-id","10":"name","11":"rar","setid":"first","sig":"alpha=="},
    {"0":"ignore","10":"other","11":"rar","19":"second","sig":"beta"},
    {"0":"fixture-part2","10":"part2","11":"rar","19":"first","sig":"gamma"}]}
    """

@Test func easynewsUsesConfiguredOrderAndSendsOnlyTheNZBToSABnzbd() async throws {
    let nzb = "<nzb><file/></nzb>"
    let transport = EasynewsTestTransport([(200, searchResponse), (200, nzb), (200, #"{"status":true,"nzo_ids":["job"]}"#)])
    let easynews = try #require(EasynewsClient(username: "fixture-user", password: " fixture:secret ", transport: transport))
    var preferences = IndexerPreferences()
    for _ in preferences.order.dropFirst() { preferences.move(.easynews, by: -1) }
    let resolver = NZBResolver(transport: transport, preferences: preferences, easynews: easynews)
    let link = try NZBLink("nzblnk:?h=header%2B%20%26&t=Fixture&p=archive-only")
    guard case .file(let file) = try await resolver.resolve(link) else {
        Issue.record("Easynews should resolve to the downloaded file.")
        return
    }
    let connection = try ServerConnection(address: "https://sab.example/api", apiKey: "sab-only")
    _ = try await SABClient(transport: transport).send(file, category: "Movies", connection: connection,
                                                       title: link.title, password: link.password)
    let requests = await transport.requests
    #expect(requests.compactMap { $0.url?.host } == ["members.easynews.com", "members.easynews.com", "sab.example"])
    let search = try #require(requests.first)
    #expect(search.url?.path == "/2.0/search/solr-search")
    #expect(search.url?.absoluteString.contains("sbj=header%2B+%26") == true)
    #expect(search.url?.absoluteString.contains("archive-only") == false)
    let download = try #require(requests.dropFirst().first)
    #expect(download.url?.path == "/2.0/api/dl-nzb")
    #expect(download.httpMethod == "POST")
    #expect(search.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(download.value(forHTTPHeaderField: "Authorization") == nil)
    let form = String(decoding: try #require(download.httpBody), as: UTF8.self)
    #expect(form.contains("name=\"0&sig=alpha==\"\r\n\r\nfixture-id|bmFtZQ:cmFy"))
    #expect(form.contains("fixture-part2"))
    #expect(!form.contains("ignore"))
    let submission = try #require(requests.last)
    let body = String(decoding: try #require(submission.httpBody), as: UTF8.self)
    #expect(body.contains(nzb) && body.contains("archive-only"))
    #expect(!body.contains("fixture-user") && !body.contains("fixture:secret"))
    #expect(submission.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test func easynewsCanExportAnNZBWithTheOriginalLinkMetadata() async throws {
    let transport = EasynewsTestTransport([(200, searchResponse), (200, "<nzb><file/></nzb>")])
    let easynews = try #require(EasynewsClient(username: "user", password: "secret", transport: transport))
    var preferences = IndexerPreferences()
    for _ in preferences.order.dropFirst() { preferences.move(.easynews, by: -1) }
    let resolver = NZBResolver(transport: transport, preferences: preferences, easynews: easynews)
    let file = try await resolver.fileForExport(NZBLink("nzblnk:?h=header&t=Fixture&p=archive-only"))
    #expect(file.title == "Fixture")
    #expect(String(decoding: file.data, as: UTF8.self).contains("archive-only"))
    #expect(await transport.requests.count == 2)
}

@Test func anOldIndexerOrderAppendsEasynewsWithoutChangingExistingOrder() throws {
    let saved = Data(#"{"order":["NewzBay","NZBKing"],"disabled":["NZBIndex"]}"#.utf8)
    let preferences = try JSONDecoder().decode(IndexerPreferences.self, from: saved)
    #expect(Array(preferences.order.prefix(2)) == [.newzBay, .nzbKing])
    #expect(preferences.order.last == .easynews)
    #expect(preferences.disabled == [.nzbIndex])
}

@Test func disabledEasynewsAndIncompleteLoginAreSkipped() async throws {
    #expect(EasynewsClient(username: "", password: "secret") == nil)
    #expect(EasynewsClient(username: "user", password: "") == nil)
    let transport = EasynewsTestTransport([(200, #"{"data":{"content":[{"id":"fixture"}]},"error":false}"#)])
    let easynews = try #require(EasynewsClient(username: "user", password: "secret", transport: transport))
    var preferences = IndexerPreferences()
    for _ in preferences.order.dropFirst() { preferences.move(.easynews, by: -1) }
    preferences.setEnabled(false, for: .easynews)
    let resolver = NZBResolver(transport: transport, preferences: preferences, easynews: easynews)
    _ = try await resolver.resolve(NZBLink("nzblnk:?h=header"))
    #expect(await transport.requests.compactMap { $0.url?.host } == ["nzbindex.com"])
}

@Test(arguments: [401, 403, 302])
func easynewsFallsBackAfterUnsuccessfulSearch(status: Int) async throws {
    let transport = EasynewsTestTransport([(status, ""), (200, #"{"data":{"content":[{"id":"fixture"}]},"error":false}"#)])
    let easynews = try #require(EasynewsClient(username: "user", password: "secret", transport: transport))
    var preferences = IndexerPreferences()
    for _ in preferences.order.dropFirst() { preferences.move(.easynews, by: -1) }
    let resolver = NZBResolver(transport: transport, preferences: preferences, easynews: easynews)
    _ = try await resolver.resolve(NZBLink("nzblnk:?h=header"))
    #expect(await transport.requests.compactMap { $0.url?.host } == ["members.easynews.com", "nzbindex.com"])
    #expect(await transport.requests.last?.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test(arguments: ["<html>Sign in</html>", "<nzb/>"])
func easynewsRejectsInvalidOrEmptyNZBs(response: String) async throws {
    let transport = EasynewsTestTransport([(200, searchResponse), (200, response)])
    let easynews = try #require(EasynewsClient(username: "user", password: "secret", transport: transport))
    await #expect(throws: RelayError.self) { try await easynews.fetch(NZBLink("nzblnk:?h=header")) }
}

@Test(arguments: [401, 403])
func easynewsReportsWhetherAccessFailedAtSearchOrDownload(status: Int) async throws {
    let link = try NZBLink("nzblnk:?h=header")
    for (phase, replies) in [
        ("Easynews rejected the sign-in during search (HTTP 401).", [(401, "")]),
        ("Easynews rejected the sign-in during NZB download (HTTP 401).", [(200, searchResponse), (401, "")]),
        ("Easynews denied the search request (HTTP 403).", [(403, "")]),
        ("Easynews denied the NZB download (HTTP 403).", [(200, searchResponse), (403, "")])
    ] where replies.last?.0 == status {
        let transport = EasynewsTestTransport(replies)
        let easynews = try #require(EasynewsClient(username: "user", password: "secret", transport: transport))
        do {
            _ = try await easynews.fetch(link)
            Issue.record("An access error must not return an NZB.")
        } catch {
            #expect(error.localizedDescription == Localization.string(String.LocalizationValue(stringLiteral: phase), table: "Errors"))
        }
    }
}


@Test func easynewsCredentialsAreOnlySuppliedForTheFirstHTTPSBasicChallengeOnItsHost() {
    let host = "members.easynews.com"
    let transport = EasynewsTransport(host: host, username: "fixture-user", password: "fixture-secret")
    let task = URLSession.shared.dataTask(with: URL(string: "https://members.easynews.com")!)
    defer { task.cancel() }
    func credential(host: String, port: Int = 443, scheme: String = "https", previousFailures: Int = 0,
                    method: String = NSURLAuthenticationMethodHTTPBasic) -> URLCredential? {
        let space = URLProtectionSpace(host: host, port: port, protocol: scheme, realm: "Easynews", authenticationMethod: method)
        let challenge = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: nil,
                                                   previousFailureCount: previousFailures, failureResponse: nil,
                                                   error: nil, sender: ChallengeSender())
        var credential: URLCredential?
        transport.urlSession(.shared, task: task, didReceive: challenge) { _, response in credential = response }
        return credential
    }
    let login = credential(host: host)
    #expect(login?.user == "fixture-user" && login?.password == "fixture-secret")
    #expect(login?.persistence == URLCredential.Persistence.none)
    #expect(credential(host: "elsewhere.example") == nil)
    #expect(credential(host: host, port: 444) == nil)
    #expect(credential(host: host, scheme: "http") == nil)
    #expect(credential(host: host, previousFailures: 1) == nil)
    #expect(credential(host: host, method: NSURLAuthenticationMethodHTTPDigest) == nil)
}

private final class ChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}

@Test func indexerTestUsesTheBuiltInEasynewsSearchAndValidatesTheFile() async throws {
    let transport = EasynewsTestTransport([(200, searchResponse), (200, "<nzb><file/></nzb>")])
    try await IndexerConnectionTest.run(.easynews, link: "", username: "fixture-user",
                                        password: "fixture-secret", transport: transport)
    let requests = await transport.requests
    #expect(requests.compactMap { $0.url?.host } == ["members.easynews.com", "members.easynews.com"])
    #expect(requests.first?.url?.query?.contains("sbj=TEST") == true)
}

@Test func indexerTestSearchesOnlyTheSelectedServiceAndUsesTheEnteredKey() async throws {
    let id = "0123456789abcdef0123456789abcdef"
    let result = """
        <rss><channel><item><title>Test Release</title><guid>\(id)</guid></item></channel></rss>
        """
    let transport = EasynewsTestTransport([(200, result), (200, "<nzb><file/></nzb>")])
    try await IndexerConnectionTest.run(.newzBay, link: "nzblnk:?h=fixture&t=Test+Release",
                                        apiKey: " test-key ", transport: transport)
    let requests = await transport.requests
    #expect(requests.compactMap { $0.url?.host } == ["newzbay.cc", "newzbay.cc"])
    #expect(requests.allSatisfy { $0.url?.query?.contains("apikey=test-key") == true })
}

@Test func indexerTestDoesNotFallBackWhenTheSelectedServiceRejectsTheRequest() async throws {
    let transport = EasynewsTestTransport([(401, "")])
    await #expect(throws: RelayError.self) {
        try await IndexerConnectionTest.run(.easynews, link: "", username: "fixture-user",
                                            password: "fixture-secret", transport: transport)
    }
    #expect(await transport.requests.count == 1)
}

@Test func indexerTestForPublicProviderDownloadsTheNZBWithoutSABnzbd() async throws {
    let transport = EasynewsTestTransport([
        (200, #"{"data":{"content":[{"id":"fixture"}]},"error":false}"#), (200, "<nzb><file/></nzb>")
    ])
    try await IndexerConnectionTest.run(.nzbIndex, link: "nzblnk:?h=fixture&t=Test+Release", transport: transport)
    #expect(await transport.requests.compactMap { $0.url?.path } == ["/api/search", "/api/download/fixture.nzb"])
}
