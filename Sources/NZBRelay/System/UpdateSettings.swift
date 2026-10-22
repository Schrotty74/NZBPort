import AppKit
import Foundation
import Observation
import RelayCore

@MainActor @Observable
final class UpdateSettings {
    private static let preferenceKey = "includeTestUpdates"
    private let defaults: UserDefaults
    private let service: ReleaseUpdates
    private let currentVersion: String

    var includePrereleases: Bool {
        didSet { defaults.set(includePrereleases, forKey: Self.preferenceKey) }
    }
    private(set) var checking = false
    private(set) var available: ReleaseUpdate?
    private(set) var message: String.LocalizationValue?

    init(defaults: UserDefaults = .standard, service: ReleaseUpdates = ReleaseUpdates(), currentVersion: String? = nil) {
        self.defaults = defaults
        self.service = service
        self.currentVersion = currentVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2"
        includePrereleases = defaults.bool(forKey: Self.preferenceKey)
    }

    func check() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        message = nil
        do {
            if let update = try await service.latest(currentVersion: currentVersion, includePrereleases: includePrereleases) {
                available = update
                message = "Version \(update.version) is available."
            } else {
                available = nil
                message = "You are using the latest version."
            }
        } catch {
            available = nil
            message = "Could not check for updates."
        }
    }

    func openAvailableRelease() {
        guard let update = available, update.url.scheme == "https", update.url.host == "github.com",
              update.url.path.hasPrefix("/Schrotty74/NZBPort/releases/tag/"),
              update.url.user == nil, update.url.password == nil else { return }
        NSWorkspace.shared.open(update.url)
    }
}
