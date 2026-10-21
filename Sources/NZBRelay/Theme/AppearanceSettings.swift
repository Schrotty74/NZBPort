import AppKit
import SwiftUI
import Observation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "System"; case .light: "Hell"; case .dark: "Dunkel" }
    }
    var native: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case system, translucent, opaque
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "System"; case .translucent: "Transparent"; case .opaque: "Deckend" }
    }
}


// Appearance preferences are independent of the SABnzbd connection and download flow.
@MainActor @Observable
final class AppearanceSettings {
    var mode: AppAppearance {
        didSet {
            defaults.set(mode.rawValue, forKey: "appearance")
            onModeChange?()
        }
    }
    var background: BackgroundStyle {
        didSet { defaults.set(background.rawValue, forKey: "backgroundStyle") }
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onModeChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        background = BackgroundStyle(rawValue: defaults.string(forKey: "backgroundStyle") ?? "") ?? .system
    }
}
