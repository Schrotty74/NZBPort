import Foundation
import RelayCore
import Testing
@testable import NZBRelay

private struct BackupTestTransport: HTTPTransport {
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        HTTPResult(data: Data(#"{"categories":["*","Movies"]}"#.utf8), status: 200)
    }
}

@MainActor @Test func settingsBackupRestoresPreferencesAndResetUsesDefaults() async throws {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("preserve", forKey: "unrelatedPreference")
    let model = AppModel(defaults: defaults, client: SABClient(transport: BackupTestTransport()))
    var backup = SettingsBackup.standard
    backup.connection = .init(address: "https://sab.example.invalid", apiKey: "test-sab",
                              treasureMaps: "test-maps", newzBay: "test-bay",
                              ninjaCentral: "test-ninja", drunkenSlug: "test-slug",
                              nzbFinder: "test-finder", videothek: "test-videothek")
    backup.categories = CategoryPreferences(hidden: ["Archive"], favorites: ["Movies"])
    backup.language = .english
    backup.appearance = .dark
    backup.colorTheme = .coffee
    backup.backgroundStyle = .opaque
    backup.includeTestUpdates = true
    backup.watchedDownloadFolder = "/example/Downloads"
    backup.launchAtLogin = model.loginItemSettings.requested

    let restored = try SettingsBackup.decode(backup.encoded())
    let followUp = try await model.applySettingsBackup(restored)
    await model.task?.value
    let exported = model.settingsBackup()
    #expect(exported.connection.address == "https://sab.example.invalid/api")
    #expect(exported.connection.apiKey == backup.connection.apiKey)
    #expect(exported.connection.treasureMaps == backup.connection.treasureMaps)
    #expect(exported.connection.newzBay == backup.connection.newzBay)
    #expect(exported.connection.ninjaCentral == backup.connection.ninjaCentral)
    #expect(exported.connection.drunkenSlug == backup.connection.drunkenSlug)
    #expect(exported.connection.nzbFinder == backup.connection.nzbFinder)
    #expect(exported.connection.videothek == backup.connection.videothek)
    #expect(exported.categories == backup.categories)
    #expect(exported.language == .english && exported.appearance == .dark)
    #expect(exported.colorTheme == .coffee && exported.backgroundStyle == .opaque)
    #expect(exported.includeTestUpdates)
    #expect(exported.watchedDownloadFolder == backup.watchedDownloadFolder)
    #expect(!followUp.isEmpty && model.downloadFolder.folder == nil)

    var standard = SettingsBackup.standard
    standard.launchAtLogin = model.loginItemSettings.requested
    _ = try await model.applySettingsBackup(standard)
    #expect(!model.configured && model.screen == .settings)
    #expect(defaults.string(forKey: "sabAPIKey") == "")
    #expect(defaults.string(forKey: "videothekAPIKey") == nil)
    #expect(model.preferences == CategoryPreferences())
    #expect(model.settingsBackup().watchedDownloadFolder == nil)
    #expect(defaults.string(forKey: "unrelatedPreference") == "preserve")
}

@Test func settingsBackupRejectsUnexpectedSchemaAndUnsafeAddress() throws {
    var backup = SettingsBackup.standard
    backup.schemaVersion = 42
    let json = try backup.encoded()
    #expect(throws: RelayError.self) { try SettingsBackup.decode(json) }
    backup.connection.address = "https://user:password@sab.example.invalid"
    #expect(throws: RelayError.self) { try backup.connection.validatedServer() }
}
