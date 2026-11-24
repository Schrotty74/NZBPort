import AppKit
import SwiftUI
import Testing
@testable import NZBRelay

@MainActor
@Test(arguments: ["gearshape", "arrow.clockwise"])
func glassMenuHasVisiblyDifferentHoverAndPressStates(symbol: String) throws {
    guard #available(macOS 27.0, *) else { return }
    var images: [String: CGImage] = [:]
    for (name, hovered, pressed) in [("idle", false, false), ("hover", true, false), ("pressed", true, true)] {
        let view = InteractiveGlassMenuLabel(
            label: Image(systemName: symbol), isPressed: pressed, hovered: hovered
        )
        .environment(\.colorTheme, .coffee)
        .environment(\.colorScheme, .dark)
        .padding(24)
        .background(Color(red: 0.16, green: 0.15, blue: 0.14))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        images[name] = renderer.cgImage
    }
    let idle = try #require(images["idle"])
    let hover = try #require(images["hover"])
    let pressed = try #require(images["pressed"])
    let idlePixels = try #require(idle.dataProvider?.data) as Data
    let hoverPixels = try #require(hover.dataProvider?.data) as Data
    let pressedPixels = try #require(pressed.dataProvider?.data) as Data
    #expect(idlePixels != hoverPixels)
    #expect(hoverPixels != pressedPixels)

    if let directory = ProcessInfo.processInfo.environment["NZBPORT_GLASS_VERIFICATION_DIR"] {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, image) in images {
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: folder.appendingPathComponent("\(symbol == "gearshape" ? "gear" : "refresh")-\(name).png"))
        }
    }
}

@MainActor
@Test func glassButtonRetainsNativeMenuActionsAndSubmenus() throws {
    let name = "NZBPort.GlassMenuTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let menu = AppOptionsMenu(model: AppModel(defaults: defaults)).makeOptionsMenu()
    menu.update()
    #expect(menu.items.filter { !$0.isSeparatorItem }.count >= 10)
    #expect(menu.items.filter { $0.submenu != nil }.count >= 4)
}
