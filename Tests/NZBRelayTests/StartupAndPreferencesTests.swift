import Foundation
import Testing
import RelayCore
@testable import NZBRelay

private actor StartupTransport: HTTPTransport {
    private let response: Result<HTTPResult, Error>
    private(set) var count = 0

    init(response: Result<HTTPResult, Error>) { self.response = response }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        count += 1
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

    #expect(model.notice?.isError == true)
    #expect(model.notice?.text.contains("SABnzbd") == true)
    #expect(model.configured && model.screen == .downloads)
    #expect(!model.busy)
    #expect(defaults.string(forKey: "sabAPIKey") == "synthetic-test-key")
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
