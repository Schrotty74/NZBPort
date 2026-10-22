import Foundation
import Testing
@testable import RelayCore

private struct StubTransport: HTTPTransport {
    let result: HTTPResult
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        #expect(request.url?.absoluteString == "https://api.github.com/repos/Schrotty74/NZBPort/releases?per_page=100")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        return result
    }
}

private func response(_ entries: [[String: Any]], status: Int = 200) throws -> HTTPResult {
    HTTPResult(data: try JSONSerialization.data(withJSONObject: entries), status: status)
}

private func release(_ tag: String, prerelease: Bool = false, draft: Bool = false, url: String? = nil) -> [String: Any] {
    ["tag_name": tag, "html_url": url ?? "https://github.com/Schrotty74/NZBPort/releases/tag/\(tag)", "prerelease": prerelease, "draft": draft]
}

@Test func choosesHighestNumericVersionAndSkipsDrafts() async throws {
    let transport = StubTransport(result: try response([
        release("v0.1.9"), release("v0.1.10"), release("v9.0.0", draft: true)
    ]))
    let update = try await ReleaseUpdates(transport: transport).latest(currentVersion: "0.1.8", includePrereleases: false)
    #expect(update?.version == "v0.1.10")
}

@Test func stableOnlyByDefaultAndPrereleaseOptIn() async throws {
    let transport = StubTransport(result: try response([
        release("v0.2.0-rc.2", prerelease: true), release("v0.1.9")
    ]))
    let service = ReleaseUpdates(transport: transport)
    let stable = try await service.latest(currentVersion: "0.1.8", includePrereleases: false)
    let all = try await service.latest(currentVersion: "0.1.8", includePrereleases: true)
    #expect(stable?.version == "v0.1.9")
    #expect(all?.version == "v0.2.0-rc.2")
    #expect(all?.isPrerelease == true)
}

@Test func comparesPrereleaseIdentifiersCorrectly() async throws {
    let transport = StubTransport(result: try response([
        release("v1.0.0-rc.10", prerelease: true), release("v1.0.0-rc.2", prerelease: true)
    ]))
    let service = ReleaseUpdates(transport: transport)
    let betweenCandidates = try await service.latest(currentVersion: "1.0.0-rc.2", includePrereleases: true)
    #expect(betweenCandidates?.version == "v1.0.0-rc.10")
    #expect(betweenCandidates?.isPrerelease == true)
}

@Test func rejectsUntrustedReleaseURLs() async throws {
    let transport = StubTransport(result: try response([
        release("v0.2.0", url: "https://evil.example/Schrotty74/NZBPort/releases/tag/v0.2.0"),
        release("v0.3.0", url: "https://github.com.attacker.invalid/Schrotty74/NZBPort/releases/tag/v0.3.0"),
        release("v0.4.0", url: "https://user@github.com/Schrotty74/NZBPort/releases/tag/v0.4.0")
    ]))
    let update = try await ReleaseUpdates(transport: transport).latest(currentVersion: "0.1.0", includePrereleases: true)
    #expect(update == nil)
}

@Test func throwsForHTTPFailureOrMalformedPayload() async throws {
    let failed = ReleaseUpdates(transport: StubTransport(result: HTTPResult(data: Data(), status: 503)))
    await #expect(throws: RelayError.self) {
        try await failed.latest(currentVersion: "0.1.0", includePrereleases: false)
    }
    let malformed = ReleaseUpdates(transport: StubTransport(result: HTTPResult(data: Data("{}".utf8), status: 200)))
    await #expect(throws: RelayError.self) {
        try await malformed.latest(currentVersion: "0.1.0", includePrereleases: false)
    }
}
