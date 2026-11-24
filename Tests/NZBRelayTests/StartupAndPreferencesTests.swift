import Foundation
import Testing
import RelayCore
@testable import NZBRelay

private actor StartupTransport: HTTPTransport {
    private let response: Result<HTTPResult, Error>
    private var firstResponse: Result<HTTPResult, Error>?
    private(set) var count = 0

    init(response: Result<HTTPResult, Error>, firstResponse: Result<HTTPResult, Error>? = nil) {
        self.response = response
        self.firstResponse = firstResponse
    }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        count += 1
        if let firstResponse {
            self.firstResponse = nil
            return try firstResponse.get()
        }
        return try response.get()
    }
}

@MainActor
private func isolatedDefaults() -> (UserDefaults, String) {
    let name = "NZBPort.Tests." + UUID().uuidString
    return (UserDefaults(suiteName: name)!, name)
}

@MainActor @Test func startupRefreshLoadsCategoriesWithoutChangingHiddenChoicesOrScreen() async throws {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    defaults.set(try JSONEncoder().encode(CategoryPreferences(hidden: ["Hidden"])), forKey: "categoryPreferences")
    let transport = StartupTransport(response: .success(HTTPResult(
        data: Data(#"{"categories":["*","New","Hidden"]}"#.utf8), status: 200
    )))
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))

    await model.refreshCategoriesAtStartup()

    #expect(model.categories == ["*", "New", "Hidden"])
    #expect(model.visibleCategories == ["*", "New"])
    #expect(model.preferences.hidden == ["Hidden"])
    #expect(model.notice == nil)
    #expect(!model.busy && !model.sending)
    #expect(model.current == nil && model.screen == .downloads)
    #expect(await transport.count == 1)
}

@MainActor @Test func offlineStartupRefreshReportsErrorWithoutChangingConfiguration() async {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let transport = StartupTransport(response: .failure(URLError(.notConnectedToInternet)))
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))

    await model.refreshCategoriesAtStartup()

    #expect(await transport.count == 1)
    #expect(model.notice?.isError == true)
    #expect(model.notice?.text.contains("SABnzbd") == true)
    #expect(model.configured && model.screen == .downloads)
    #expect(!model.busy)
    #expect(defaults.string(forKey: "sabAPIKey") == "synthetic-test-key")
}

@MainActor @Test(arguments: [false, true])
func loginRefreshRecoversWhenSABnzbdBecomesReady(throughProxy: Bool) async {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let first: Result<HTTPResult, Error> = throughProxy
        ? .success(HTTPResult(data: Data(), status: 503))
        : .failure(URLError(.cannotConnectToHost))
    let transport = StartupTransport(
        response: .success(HTTPResult(data: Data(#"{"categories":["Movies"]}"#.utf8), status: 200)),
        firstResponse: first
    )
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))

    await model.refreshCategoriesAtStartup(launchedAtLogin: true, retryDelays: [.zero, .zero, .zero])

    #expect(await transport.count == 2)
    #expect(model.categories == ["Movies"])
    #expect(model.notice == nil)
}

@MainActor @Test(arguments: [401, 503])
func loginRefreshReportsPermanentOrExhaustedFailure(status: Int) async {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let transport = StartupTransport(response: .success(HTTPResult(data: Data(), status: status)))
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))

    await model.refreshCategoriesAtStartup(launchedAtLogin: true, retryDelays: [.zero, .zero, .zero])

    #expect(await transport.count == (status == 503 ? 4 : 1))
    #expect(model.notice?.isError == true)
}

@MainActor @Test func unconfiguredStartupDoesNotContactAnyServer() async {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let transport = StartupTransport(response: .failure(URLError(.badURL)))
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))

    await model.refreshCategoriesAtStartup()

    #expect(await transport.count == 0)
    #expect(model.notice == nil && model.screen == .settings)
}

@MainActor @Test func languageAndThemesPersistIndependentlyOfAppearanceAndConnection() {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let language = LanguageSettings(defaults: defaults)
    let appearance = AppearanceSettings(defaults: defaults)
    #expect(language.selection == .system)
    #expect(appearance.theme == .standard)
    language.selection = .english
    appearance.mode = .dark
    appearance.background = .opaque
    for theme in [ColorTheme.coffee, .ivory, .mint] {
        appearance.theme = theme
        let restored = AppearanceSettings(defaults: defaults)
        #expect(restored.theme == theme)
        #expect(restored.mode == .dark && restored.background == .opaque)
        #expect(LanguageSettings(defaults: defaults).selection == .english)
    }
    language.selection = .german
    #expect(LanguageSettings(defaults: defaults).effectiveLanguage == .german)
    language.selection = .system
    #expect(LanguageSettings(defaults: defaults).selection == .system)
    #expect(defaults.string(forKey: "sabAPIKey") == "synthetic-test-key")
}

@MainActor @Test func newznabKeysCanBeSavedAndClearedIndependently() async throws {
    let (defaults, domain) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-sab-key", forKey: "sabAPIKey")
    let transport = StartupTransport(response: .success(HTTPResult(
        data: Data(#"{"categories":[]}"#.utf8), status: 200
    )))
    let client = SABClient(transport: transport)
    let model = AppModel(defaults: defaults, client: client)

    model.treasureMapsKey = "unsaved"
    model.newzBayKey = "unsaved"
    model.ninjaCentralKey = "unsaved"
    model.drunkenSlugKey = "unsaved"
    model.nzbFinderKey = "unsaved"
    model.videothekKey = "unsaved"
    model.openSettings()
    #expect(model.treasureMapsKey.isEmpty)
    #expect(model.newzBayKey.isEmpty)
    #expect(model.ninjaCentralKey.isEmpty)
    #expect(model.drunkenSlugKey.isEmpty)
    #expect(model.nzbFinderKey.isEmpty)
    #expect(model.videothekKey.isEmpty)

    model.treasureMapsKey = " synthetic-treasure-key "
    model.newzBayKey = " synthetic-newzbay-key "
    model.ninjaCentralKey = " synthetic-ninja-key "
    model.drunkenSlugKey = " synthetic-drunken-key "
    model.nzbFinderKey = " synthetic-finder-key "
    model.videothekKey = " synthetic-videothek-key "
    model.save()
    await model.task?.value
    let restored = AppModel(defaults: defaults, client: client)
    #expect(restored.treasureMapsKey == "synthetic-treasure-key")
    #expect(restored.newzBayKey == "synthetic-newzbay-key")
    #expect(restored.ninjaCentralKey == "synthetic-ninja-key")
    #expect(restored.drunkenSlugKey == "synthetic-drunken-key")
    #expect(restored.nzbFinderKey == "synthetic-finder-key")
    #expect(restored.videothekKey == "synthetic-videothek-key")

    restored.treasureMapsKey = " "
    restored.ninjaCentralKey = " "
    restored.drunkenSlugKey = " "
    restored.nzbFinderKey = " "
    restored.videothekKey = " "
    restored.save()
    await restored.task?.value
    #expect(defaults.string(forKey: "treasureMapsAPIKey") == nil)
    #expect(defaults.string(forKey: "ninjaCentralAPIKey") == nil)
    #expect(defaults.string(forKey: "drunkenSlugAPIKey") == nil)
    #expect(defaults.string(forKey: "nzbFinderAPIKey") == nil)
    #expect(defaults.string(forKey: "videothekAPIKey") == nil)
    #expect(defaults.string(forKey: "newzBayAPIKey") == "synthetic-newzbay-key")
    #expect(defaults.string(forKey: "sabAPIKey") == "synthetic-sab-key")
}
