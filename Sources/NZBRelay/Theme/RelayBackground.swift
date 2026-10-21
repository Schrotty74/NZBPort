import AppKit
import SwiftUI

struct RelayBackground: View {
    let style: BackgroundStyle
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency || style == .opaque {
            RelayTheme.solidBackground
        } else {
            NativeMaterial(material: RelayTheme.material(for: style))
        }
    }
}

private struct NativeMaterial: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.material = material
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
