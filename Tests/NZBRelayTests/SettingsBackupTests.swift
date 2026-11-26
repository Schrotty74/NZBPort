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
                              nzbFinder: "test-finder", videothek: "test-videothek",
                              easynews: .init(username: "fixture-user", password: " fixture-password "))
    backup.categories = CategoryPreferences(hidden: ["Archive"], favorites: ["Movies"])
    backup.categories.recognition.automaticallySends = true
    backup.categories.recognition[.movies] = "Movies"
    backup.categories.recognition.rules = [.init(pattern: "Fixture", category: "Movies")]
    var indexers = IndexerPreferences()
    indexers.move(.newzBay, by: -4)
    indexers.setEnabled(false, for: .newzBay)
    indexers.move(.easynews, by: -9)
    indexers.setEnabled(false, for: .easynews)
    backup.indexers = indexers
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
    #expect(exported.indexers == indexers)
    let reopened = AppModel(defaults: defaults, client: SABClient(transport: BackupTestTransport()))
    #expect(reopened.indexerPreferences == indexers)
    #expect(reopened.easynewsUsername == "fixture-user")
    #expect(reopened.easynewsPassword == " fixture-password ")
    model.easynewsPassword = "unsaved"
    #expect(model.settingsBackup().connection.easynews?.password == " fixture-password ")
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
    #expect(defaults.data(forKey: "easynewsLogin") == nil)
    #expect(model.easynewsUsername.isEmpty && model.easynewsPassword.isEmpty)
    #expect(model.preferences == CategoryPreferences())
    #expect(model.indexerPreferences == IndexerPreferences())
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

@Test func existingSettingsBackupWithoutRecognitionKeepsManualCategorySelection() throws {
    let encoded = try SettingsBackup.standard.encoded()
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["categories"] = ["favorites": ["TV"], "hidden": []]
    let restored = try SettingsBackup.decode(JSONSerialization.data(withJSONObject: object))
    #expect(restored.categories.favorites == ["TV"])
    #expect(restored.categories.recognition == CategoryRecognition())
    #expect(restored.indexers == nil)
    #expect(restored.connection.easynews == nil)
}
