import SwiftUI

enum RelayGlass {
    static var interactiveControl: Glass {
        if #available(macOS 27.0, *) {
            .regular.interactive()
        } else {
            .regular
        }
    }
}

/// Shared native control styles for macOS 26 and later.
extension View {
    @ViewBuilder
    func relayInteractiveRoundControl() -> some View {
        if #available(macOS 27.0, *) {
            buttonStyle(InteractiveGlassMenuButtonStyle())
        } else {
            self
        }
    }

    func relayGlassControls() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
    }

    func relayPrimaryAction() -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
    }
}

@available(macOS 27.0, *)
struct InteractiveGlassMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InteractiveGlassMenuLabel(label: configuration.label, isPressed: configuration.isPressed)
    }
}

@available(macOS 27.0, *)
struct InteractiveGlassMenuLabel<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @State var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorTheme) private var colorTheme

    private var highlighted: Bool { enabled && (hovered || isPressed) }

    var body: some View {
        label
            .frame(width: 28, height: 28)
            .foregroundStyle(highlighted ? colorTheme.accent : .primary)
            .background {
                Circle().fill(.clear)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .overlay {
                Circle().strokeBorder(colorTheme.accent.opacity(highlighted ? 0.8 : 0), lineWidth: 1.5)
            }
            .modifier(RelayControlBorder(shape: Circle()))
            .scaleEffect(reduceMotion || !enabled ? 1 : isPressed ? 0.82 : hovered ? 1.18 : 1)
            .shadow(color: colorTheme.accent.opacity(highlighted ? 0.35 : 0), radius: highlighted ? 8 : 0)
            .contentShape(.circle)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: hovered)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: isPressed)
    }
}
