import AppKit
import SwiftUI

/// The palettes are independent of the system/light/dark appearance setting.
enum ColorTheme: String, CaseIterable, Identifiable {
    case standard, coffee, ivory, mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: L("Standard")
        case .coffee: L("Coffee")
        case .ivory: L("Elfenbein")
        case .mint: L("Minze")
        }
    }

    var accent: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            switch self {
            case .standard:
                return NSColor(red: 0.16, green: 0.38, blue: 0.85, alpha: 1)
            case .coffee:
                return dark
                    ? NSColor(red: 0.86, green: 0.65, blue: 0.43, alpha: 1)
                    : NSColor(red: 0.45, green: 0.27, blue: 0.16, alpha: 1)
            case .ivory:
                return dark
                    ? NSColor(red: 0.91, green: 0.80, blue: 0.52, alpha: 1)
                    : NSColor(red: 0.48, green: 0.36, blue: 0.12, alpha: 1)
            case .mint:
                return dark
                    ? NSColor(red: 0.43, green: 0.82, blue: 0.64, alpha: 1)
                    : NSColor(red: 0.13, green: 0.42, blue: 0.31, alpha: 1)
            }
        })
    }

    var windowColor: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            switch self {
            case .standard:
                return .windowBackgroundColor
            case .coffee:
                return dark
                    ? NSColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 1)
                    : NSColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1)
            case .ivory:
                return dark
                    ? NSColor(red: 0.12, green: 0.115, blue: 0.10, alpha: 1)
                    : NSColor(red: 0.98, green: 0.965, blue: 0.90, alpha: 1)
            case .mint:
                return dark
                    ? NSColor(red: 0.06, green: 0.14, blue: 0.12, alpha: 1)
                    : NSColor(red: 0.90, green: 0.96, blue: 0.92, alpha: 1)
            }
        }
    }
}
