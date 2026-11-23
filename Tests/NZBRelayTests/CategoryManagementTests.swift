import Foundation
import Testing
import RelayCore
@testable import NZBRelay

private actor CategoryManagementTransport: HTTPTransport {
    enum Outcome { case success, writeFailure, refreshFailure }
    let outcome: Outcome
    private(set) var writes = 0
    private(set) var requests: [URLRequest] = []
    private var names = ["*", "movies"]
    init(_ outcome: Outcome = .success) { self.outcome = outcome }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        let fields = URLComponents(string: "https://fixture.invalid/?" + body)?.queryItems ?? []
        let mode = fields.first { $0.name == "mode" }?.value
        if mode == "get_cats" {
            if outcome == .refreshFailure && writes > 0 { throw URLError(.notConnectedToInternet) }
            return HTTPResult(data: try JSONSerialization.data(withJSONObject: ["categories": names]), status: 200)
        }
        if mode == "set_config" {
            writes += 1
            if outcome == .writeFailure { throw URLError(.timedOut) }
            names.append((fields.first { $0.name == "name" }?.value ?? "").lowercased())
        }
        return HTTPResult(data: try JSONSerialization.data(withJSONObject: ["config": ["categories": names.map { ["name": $0] }]]), status: 200)
    }
}

@MainActor private func categoryDefaults(configured: Bool = true) -> (UserDefaults, String) {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    if configured {
        defaults.set("https://saved.example.invalid/api", forKey: "serverAddress")
        defaults.set("synthetic-key", forKey: "sabAPIKey")
    }
    return (defaults, domain)
}

@MainActor @Test func categoryScreenUsesSavedConnectionAndCreationRefreshesServerList() async {
    let (defaults, domain) = categoryDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryManagementTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.address = "https://unsaved.example.invalid/api"
    model.key = "unsaved-key"
    model.openCategories()
    await model.task?.value
    #expect(model.screen == .categories && model.categories == ["*", "movies"])
    #expect(await transport.writes == 0)
    model.newCategoryName = " Documentaries "
    model.addCategory()
    await model.task?.value
    #expect(model.categories == ["*", "movies", "documentaries"])
    #expect(model.newCategoryName.isEmpty && model.notice?.isError == false)
    #expect(!model.busy && !model.categoryMutationInProgress)
    #expect(await transport.writes == 1)
    #expect(await transport.requests.allSatisfy { $0.url?.host == "saved.example.invalid" })
}

@MainActor @Test func duplicateCategoryDoesNotWriteAndKeepsNameForCorrection() async {
    let (defaults, domain) = categoryDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryManagementTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.newCategoryName = "MOVIES"
    model.addCategory()
    await model.task?.value
    #expect(await transport.writes == 0)
    #expect(model.newCategoryName == "MOVIES" && model.notice?.isError == true)
    #expect(!model.categoryMutationInProgress && !model.busy)
}

@MainActor @Test func categoryWriteFailureDoesNotRetryOrClaimSuccess() async {
    let (defaults, domain) = categoryDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryManagementTransport(.writeFailure)
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.newCategoryName = "Archive"
    model.addCategory()
    await model.task?.value
    #expect(await transport.writes == 1)
    #expect(model.newCategoryName == "Archive" && model.notice?.isError == true)
    #expect(!model.categoryMutationInProgress && !model.busy)
}

@MainActor @Test func confirmedCreationAndRefreshFailureDoesNotResubmitCategory() async {
    let (defaults, domain) = categoryDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryManagementTransport(.refreshFailure)
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.newCategoryName = "Archive"
    model.addCategory()
    await model.task?.value
    #expect(await transport.writes == 1)
    #expect(model.newCategoryName.isEmpty && model.notice?.isError == true)
    #expect(!model.categoryMutationInProgress && !model.busy)
}

@MainActor @Test func unconfiguredCategoryScreenDoesNotContactServer() async {
    let (defaults, domain) = categoryDefaults(configured: false)
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryManagementTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.openCategories()
    #expect(model.screen == .categories)
    model.newCategoryName = "Archive"
    model.addCategory()
    #expect(await transport.requests.isEmpty)
}

@MainActor @Test func incomingLinkDoesNotCancelCategoryCreation() async {
    let (defaults, domain) = categoryDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = CategoryManagementTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.newCategoryName = "Archive"
    model.addCategory()
    let creation = model.task
    #expect(model.categoryMutationInProgress)
    model.receive([URL(string: "nzblnk:?h=synthetic&t=Title")!])
    #expect(model.current == nil && model.pending.count == 1)
    model.loadCategories()
    await creation?.value
    await model.task?.value
    #expect(await transport.writes == 1)
    #expect(model.current?.title == "Title" && model.pending.isEmpty)
    #expect(model.categories.contains("archive"))
}
