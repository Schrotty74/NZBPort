import SwiftUI

/// Shared native control styles for macOS 26 and later.
extension View {
    func relayGlassControls() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
    }

    func relayPrimaryAction() -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(RelayTheme.accent)
    }
}
