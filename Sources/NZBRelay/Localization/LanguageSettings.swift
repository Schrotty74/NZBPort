import AppKit
import Observation
import RelayCore

/// Uses the app's own preference; never changes macOS language preferences.
@MainActor @Observable
final class LanguageSettings {
    var selection: AppLanguage {
        didSet {
            defaults.set(selection.rawValue, forKey: Localization.preferenceKey)
            onChange?()
        }
    }
    private(set) var preferredLanguages = Locale.preferredLanguages
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = AppLanguage(rawValue: defaults.string(forKey: Localization.preferenceKey) ?? "") ?? .system
    }

    var effectiveLanguage: AppLanguage {
        AppLanguage.resolved(selection, preferredLanguages: preferredLanguages)
    }

    func refreshSystemLanguage() {
        preferredLanguages = Locale.preferredLanguages
        if selection == .system { onChange?() }
    }
}

func L(_ value: String.LocalizationValue) -> String {
    Localization.string(value)
}

extension AppLanguage {
    var title: String {
        switch self {
        case .system: L("System")
        case .german: "Deutsch"
        case .english: "English"
        }
    }
}
