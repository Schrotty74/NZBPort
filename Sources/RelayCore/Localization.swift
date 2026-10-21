import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case german
    case english

    public var id: String { rawValue }

    public static func resolved(_ choice: AppLanguage, preferredLanguages: [String]) -> AppLanguage {
        guard choice == .system else { return choice }
        for preferred in preferredLanguages {
            let code = Locale(identifier: preferred).language.languageCode?.identifier.lowercased()
            if code == "de" { return .german }
            if code == "en" { return .english }
        }
        return .english
    }
}

public enum Localization {
    public static let preferenceKey = "appLanguage"

    public static var language: AppLanguage {
        let choice = UserDefaults.standard.string(forKey: preferenceKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        return .resolved(choice, preferredLanguages: Locale.preferredLanguages)
    }

    public static var locale: Locale {
        Locale(identifier: language == .german ? "de" : "en")
    }

    public static func string(
        _ value: String.LocalizationValue,
        table: String = "Interface",
        language: AppLanguage? = nil,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let resolved = language.map { AppLanguage.resolved($0, preferredLanguages: preferredLanguages) } ?? self.language
        let bundle = resourceBundle(for: resolved)
        let locale = Locale(identifier: resolved == .german ? "de" : "en")
        return String(localized: value, table: table, bundle: bundle, locale: locale)
    }

    /// The package resource bundle is located relative to the host app or test bundle.
    /// This avoids embedding a build-machine path in the app binary.
    public static func resourceBundle(for language: AppLanguage? = nil) -> Bundle {
        let resolved = language.map { AppLanguage.resolved($0, preferredLanguages: Locale.preferredLanguages) } ?? self.language
        let code = resolved == .german ? "de" : "en"
        let anchorBundle = Bundle(for: RelayCoreBundleAnchor.self)
        let candidates = [Bundle.main, anchorBundle].flatMap { bundle in
            [bundle.resourceURL, bundle.bundleURL, bundle.bundleURL.deletingLastPathComponent()]
        }.compactMap { $0 }

        for directory in candidates {
            let packageBundleURL = directory.appendingPathComponent("NZBRelay_RelayCore.bundle", isDirectory: true)
            if let packageBundle = Bundle(url: packageBundleURL),
               let localizedPath = packageBundle.path(forResource: code, ofType: "lproj"),
               let localizedBundle = Bundle(path: localizedPath) {
                return localizedBundle
            }
            let localizedURL = directory.appendingPathComponent("\(code).lproj", isDirectory: true)
            if let localizedBundle = Bundle(url: localizedURL) { return localizedBundle }
        }
        return anchorBundle
    }
}

private final class RelayCoreBundleAnchor: NSObject {}
