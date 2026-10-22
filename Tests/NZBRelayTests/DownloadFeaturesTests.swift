import Foundation
import Testing
import RelayCore
@testable import NZBRelay

private actor FeatureTransport: HTTPTransport {
    private(set) var uploads = 0
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        if request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart") == true {
            uploads += 1
            return HTTPResult(data: Data(#"{"status":true,"nzo_ids":["job-test"]}"#.utf8), status: 200)
        }
        return HTTPResult(data: Data(#"{"categories":["*","Movies"]}"#.utf8), status: 200)
    }
}

@Test func duplicateIdentityIgnoresTitleButSeparatesServersAndExpires() throws {
    let first = DownloadSubmission.link(try NZBLink("nzblnk:?h=test&t=First"))
    let second = DownloadSubmission.link(try NZBLink("nzblnk:?h=test&t=Second"))
    let a = URL(string: "https://a.example/api")!, b = URL(string: "https://b.example/api")!
    #expect(first.fingerprint(server: a) == second.fingerprint(server: a))
    #expect(first.fingerprint(server: a) != first.fingerprint(server: b))
    var ledger = SubmissionLedger()
    let time = Date(timeIntervalSince1970: 1000)
    let key = first.fingerprint(server: a)
    ledger.record(key, now: time)
    let recent = ledger.contains(key, now: time.addingTimeInterval(599))
    let expired = ledger.contains(key, now: time.addingTimeInterval(601))
    #expect(recent)
    #expect(!expired)
}

@Test func favoritesMigrateAndSurviveVisibilityAndServerRefreshes() throws {
    var preferences = try JSONDecoder().decode(CategoryPreferences.self, from: Data(#"{"hidden":["Hidden"]}"#.utf8))
    #expect(preferences.favorites.isEmpty)
    preferences.setFavorite(true, category: "Movies")
    preferences.setFavorite(true, category: "TV")
    preferences.moveFavorite("TV", by: -1)
    #expect(preferences.visible(in: ["*", "Movies", "TV", "New", "Hidden"]) == ["TV", "Movies", "*", "New"])
    preferences.setVisible(false, category: "TV")
    let restored = try JSONDecoder().decode(CategoryPreferences.self, from: JSONEncoder().encode(preferences))
    #expect(restored.isFavorite("TV"))
    #expect(restored.visible(in: ["*", "Movies", "TV"]) == ["Movies", "*"])
}

@Test func notificationBaselineSkipsOldJobsAndWaitsForTerminalState() {
    var tracker = CompletionTracker()
    let old = SABHistoryJob(id: "old", title: "Old", status: "Completed", failed: false)
    #expect(tracker.observe([old]).isEmpty)
    tracker.track(["new"])
    let extracting = SABHistoryJob(id: "new", title: "New", status: "Extracting", failed: false)
    #expect(tracker.observe([extracting, old]).isEmpty)
    let completed = SABHistoryJob(id: "new", title: "New", status: "Completed", failed: false)
    #expect(tracker.observe([completed, old]).map(\.id) == ["new"])
    #expect(tracker.observe([completed, old]).isEmpty)
    let failed = SABHistoryJob(id: "failure", title: "Failed", status: "Failed", failed: true)
    #expect(tracker.observe([failed, completed]).map(\.id) == ["failure"])
}

@MainActor @Test func fileSubmissionWaitsForCategoryAndDuplicateNeedsConfirmation() async throws {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("Fixture.nzb")
    try Data("<?xml version=\"1.0\"?><nzb/>".utf8).write(to: file)
    let transport = FeatureTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.receive([file])
    await model.task?.value
    #expect(await transport.uploads == 0)
    model.send(category: "Movies")
    await model.task?.value
    #expect(await transport.uploads == 1)
    #expect(model.current == nil && !model.sending)
    model.receive([file])
    await model.task?.value
    model.send(category: "Movies")
    #expect(model.duplicateCategory == "Movies")
    #expect(await transport.uploads == 1)
    model.confirmDuplicate()
    await model.task?.value
    #expect(await transport.uploads == 2)
}
