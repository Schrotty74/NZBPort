import SwiftUI

@MainActor
enum RelayControlShape {
    /// Notices sit close to the window edge, so on macOS 27 their corners
    /// follow the window's container shape. Keep the existing radius on 26.
    static var notice: AnyShape {
        if #available(macOS 27, *) {
            AnyShape(ConcentricRectangle(
                corners: .concentric(minimum: .fixed(RelayTheme.rowRadius)),
                isUniform: true
            ))
        } else {
            AnyShape(RoundedRectangle(cornerRadius: RelayTheme.rowRadius, style: .continuous))
        }
    }
}

/// Adds the system-requested outline to our custom-shaped controls on macOS 27.
/// macOS 26 keeps the existing native appearance unchanged.
struct RelayControlBorder<S: Shape>: ViewModifier {
    @Environment(\.accessibilityShowBorders) private var showBorders

    let shape: S
    var tint: Color = .primary

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 27, *), showBorders {
            content.overlay {
                shape.stroke(tint.opacity(0.82), lineWidth: 1.25)
                    .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}
