import AppKit
import SwiftUI

struct RelayBackground: View {
    let style: BackgroundStyle
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorTheme) private var colorTheme

    var body: some View {
        if reduceTransparency || style == .opaque {
            Color(nsColor: colorTheme.windowColor)
        } else {
            ZStack {
                NativeMaterial(material: RelayTheme.material(for: style))
                Color(nsColor: colorTheme.windowColor).opacity(colorTheme == .standard ? 0 : 0.16)
            }
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
