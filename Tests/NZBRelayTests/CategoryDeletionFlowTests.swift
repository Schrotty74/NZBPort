import Foundation
import Testing
import RelayCore
@testable import NZBRelay

private actor CategoryDeletionFlowTransport: HTTPTransport {
    enum Outcome { case success, writeFailure, refreshFailure }
    let outcome: Outcome
    private var names = ["*", "movies", "series"]
    private(set) var deletes = 0
    init(_ outcome: Outcome = .success) { self.outcome = outcome }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        let fields = URLComponents(string: "https://fixture.invalid/?" + String(decoding: request.httpBody ?? Data(), as: UTF8.self))?.queryItems ?? []
        let mode = fields.first { $0.name == "mode" }?.value
        if mode == "get_cats" {
            if deletes > 0 && outcome == .refreshFailure { throw URLError(.notConnectedToInternet) }
            return HTTPResult(data: try JSONSerialization.data(withJSONObject: ["categories": names]), status: 200)
        }
        if mode == "del_config" {
            deletes += 1
            if outcome == .writeFailure { throw URLError(.timedOut) }
            let name = fields.first { $0.name == "keyword" }?.value
            names.removeAll { $0 == name }
            return HTTPResult(data: Data(#"{"status":true}"#.utf8), status: 200)
        }
        return HTTPResult(data: try JSONSerialization.data(withJSONObject: ["config": ["categories": names.map { ["name": $0] }]]), status: 200)
    }
}

@MainActor private func deletionDefaults() -> (UserDefaults, String) {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defaults.set("https://synthetic.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-key", forKey: "sabAPIKey")
    return (defaults, domain)
}

@MainActor @Test func deletionSelectionAndCancellationDoNotDeleteAndDefaultIsProtected() async {
    let (defaults, domain) = deletionDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryDeletionFlowTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.openCategories()
    await model.task?.value
    model.requestCategoryDeletion("movies")
    #expect(model.categoryToDelete == "movies")
    #expect(await transport.deletes == 0)
    model.categoryToDelete = nil
    model.requestCategoryDeletion("*")
    #expect(model.categoryToDelete == nil)
    model.confirmCategoryDeletion("*")
    #expect(await transport.deletes == 0)
    #expect(model.categories.contains("*"))
}

@MainActor @Test func confirmedDeletionRemovesServerCategoryAndLocalDisplayPreferences() async throws {
    let (defaults, domain) = deletionDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryDeletionFlowTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.openCategories()
    await model.task?.value
    model.setFavorite(true, category: "MOVIES")
    model.setVisible(false, category: "movies")
    model.requestCategoryDeletion("movies")
    model.confirmCategoryDeletion("movies")
    await model.task?.value
    #expect(await transport.deletes == 1)
    #expect(model.categories == ["*", "series"])
    #expect(!model.preferences.isFavorite("movies") && !model.preferences.hidden.contains("movies"))
    #expect(model.notice?.isError == false && !model.categoryMutationInProgress && !model.busy)
    let data = try #require(defaults.data(forKey: "categoryPreferences"))
    let saved = try JSONDecoder().decode(CategoryPreferences.self, from: data)
    #expect(saved.hidden.isEmpty && saved.favorites.isEmpty)
}

@MainActor @Test func failedCategoryDeletionKeepsCategoryAndDisplayChoicesWithoutRetry() async {
    let (defaults, domain) = deletionDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryDeletionFlowTransport(.writeFailure)
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.openCategories()
    await model.task?.value
    model.setFavorite(true, category: "movies")
    model.requestCategoryDeletion("movies")
    model.confirmCategoryDeletion("movies")
    await model.task?.value
    #expect(await transport.deletes == 1)
    #expect(model.categories.contains("movies") && model.preferences.isFavorite("movies"))
    #expect(model.notice?.isError == true && !model.categoryMutationInProgress && !model.busy)
}

@MainActor @Test func confirmedDeletionKeepsLocalRemovalWhenListRefreshFails() async {
    let (defaults, domain) = deletionDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryDeletionFlowTransport(.refreshFailure)
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.openCategories()
    await model.task?.value
    model.requestCategoryDeletion("movies")
    model.confirmCategoryDeletion("movies")
    await model.task?.value
    #expect(await transport.deletes == 1)
    #expect(!model.categories.contains("movies"))
    #expect(model.notice?.isError == true && !model.categoryMutationInProgress && !model.busy)
}
