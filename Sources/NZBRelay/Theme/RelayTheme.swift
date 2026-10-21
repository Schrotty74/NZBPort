import AppKit
import SwiftUI

extension EnvironmentValues {
    @Entry var colorTheme: ColorTheme = .standard
}

/// Central visual values. Keep download and connection logic out of this file.
@MainActor
enum RelayTheme {
    static let solidBackground = Color(nsColor: .windowBackgroundColor)

    static let windowSize = NSSize(width: 500, height: 560)
    static let minimumWindowSize = NSSize(width: 480, height: 440)
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16
    static let rowRadius: CGFloat = 10

    static let brandFont = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let welcomeFont = Font.system(size: 26, weight: .semibold, design: .rounded)
    static let pageTitleFont = Font.system(size: 23, weight: .semibold, design: .rounded)
    static let downloadTitleFont = Font.system(size: 23, weight: .semibold)

    static func material(for style: BackgroundStyle) -> NSVisualEffectView.Material {
        style == .system ? .windowBackground : .sidebar
    }
}
