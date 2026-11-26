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
    let entries = menu.items.filter { !$0.isSeparatorItem }
    #expect(entries.map(\.title) == [
        L("NZB-Dateien öffnen …"), L("Downloads"), L("Kategorien …"), L("SABnzbd öffnen"),
        L("Einstellungen"), L("Über NZBPort")
    ])
    let settings = try #require(entries.first { $0.title == L("Einstellungen") }?.submenu)
    settings.update()
    #expect(Set(settings.items.filter { !$0.isSeparatorItem }.map(\.title)) == Set([
        L("Verbindung …"), L("Downloadordner"), L("Sprache"), L("Autostart"), L("Erscheinungsbild"), L("Sicherung")
    ]))
    let backup = try #require(settings.items.first { $0.title == L("Sicherung") }?.submenu)
    backup.update()
    #expect(backup.items.filter { !$0.isSeparatorItem }.map(\.title) == [
        L("Einstellungen exportieren …"), L("Einstellungen importieren …"), L("Einstellungen zurücksetzen …")
    ])
    let about = try #require(entries.first { $0.title == L("Über NZBPort") }?.submenu)
    about.update()
    #expect(about.items.contains { $0.title == L("Nach Updates suchen …") })
}

@MainActor
@Test func statusMenuSharesOptionsAndKeepsItsOwnActions() throws {
    let name = "NZBPort.StatusMenuTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = AppModel(defaults: defaults)
    let delegate = AppDelegate(model: model)
    let status = delegate.makeStatusMenu()
    let gear = AppOptionsMenu(model: model).makeOptionsMenu()
    let shared = titles(in: gear)
    #expect(titles(in: status) == [
        L("SABnzbd nicht eingerichtet"), L("NZBPort öffnen"), L("NZBlnk aus Zwischenablage")
    ] + shared + [L("NZBPort beenden")])
    let openSAB = try #require(status.items.first { $0.title == L("SABnzbd öffnen") })
    #expect(!delegate.validateMenuItem(openSAB))

    for title in [L("Einstellungen"), L("Über NZBPort")] {
        let statusSubmenu = try #require(status.items.first { $0.title == title }?.submenu)
        let gearSubmenu = try #require(gear.items.first { $0.title == title }?.submenu)
        #expect(titles(in: statusSubmenu) == titles(in: gearSubmenu))
    }
    let settings = try #require(status.items.first { $0.title == L("Einstellungen") }?.submenu)
    let backup = try #require(settings.items.first { $0.title == L("Sicherung") }?.submenu)
    #expect(titles(in: backup) == [
        L("Einstellungen exportieren …"), L("Einstellungen importieren …"), L("Einstellungen zurücksetzen …")
    ])
}

@MainActor private func titles(in menu: NSMenu) -> [String] {
    menu.update()
    return menu.items.filter { !$0.isSeparatorItem }.map(\.title)
}
