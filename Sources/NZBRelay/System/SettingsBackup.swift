import Foundation
import RelayCore

struct SettingsBackup: Codable, Sendable {
    static let defaultServerAddress = "http://localhost:8080/api"
    static let standard = Self(
        connection: Connection(address: defaultServerAddress, apiKey: "", treasureMaps: "", newzBay: "",
                               ninjaCentral: "", drunkenSlug: "", nzbFinder: "", videothek: ""),
        categories: CategoryPreferences(), language: .system, appearance: .system, colorTheme: .standard,
        backgroundStyle: .system, includeTestUpdates: false, downloadNotifications: false,
        launchAtLogin: false, watchedDownloadFolder: nil
    )

    struct Connection: Codable, Sendable {
        var address: String
        var apiKey: String
        var treasureMaps: String
        var newzBay: String
        var ninjaCentral: String
        var drunkenSlug: String
        var nzbFinder: String
        var videothek: String

        func validatedServer() throws -> ServerConnection? {
            let savedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let server = try ServerConnection(address: address, apiKey: savedKey.isEmpty ? "*" : savedKey)
            return savedKey.isEmpty ? nil : server
        }
    }

    static let maximumBytes = 1024 * 1024
    var format = "NZBPort for macOS"
    var schemaVersion = 1
    var connection: Connection
    var categories: CategoryPreferences
    var language: AppLanguage
    var appearance: AppAppearance
    var colorTheme: ColorTheme
    var backgroundStyle: BackgroundStyle
    var includeTestUpdates: Bool
    var downloadNotifications: Bool
    var launchAtLogin: Bool
    var watchedDownloadFolder: String?
    var indexers: IndexerPreferences? = nil

    static func read(from url: URL) throws -> Self {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= maximumBytes else {
            throw invalidBackup
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        return try decode(file.read(upToCount: maximumBytes + 1) ?? Data())
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw invalidBackup }
        let backup: Self
        do {
            backup = try JSONDecoder().decode(Self.self, from: data)
        } catch { throw invalidBackup }
        guard backup.format == "NZBPort for macOS", backup.schemaVersion == 1,
              backup.watchedDownloadFolder.map({ $0.hasPrefix("/") && !$0.contains("\0") }) ?? true else {
            throw invalidBackup
        }
        return backup
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    private static var invalidBackup: RelayError {
        .message("Choose a valid NZBPort settings backup for macOS.")
    }
}
