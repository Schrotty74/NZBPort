import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = AppModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private lazy var appearanceMenu = AppearanceMenu(settings: model.appearanceSettings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildStatusMenu()
        model.appearanceSettings.onModeChange = { [weak self] in
            guard let self else { return }
            self.window?.appearance = self.model.appearanceSettings.mode.native
        }
        showWindow()
        model.closeAfterSuccess = { [weak self] in self?.window?.close() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showWindow()
        model.receive(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.sending else { return .terminateNow }
        model.notice = Notice(text: "Der Auftrag wird noch verarbeitet. Bitte die Antwort von SABnzbd abwarten.", isError: false)
        return .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if model.sending {
            model.notice = Notice(text: "Der Auftrag wird noch verarbeitet. Bitte die Antwort von SABnzbd abwarten.", isError: false)
            return false
        }
        return true
    }

    private func showWindow() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: RelayTheme.windowSize),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "NZBPort"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.isOpaque = false
            window.backgroundColor = .windowBackgroundColor
            window.appearance = model.appearanceSettings.mode.native
            window.isReleasedWhenClosed = false
            window.minSize = RelayTheme.minimumWindowSize
            window.contentView = NSHostingView(rootView: RelayRootView(model: model))
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func settings() { showWindow(); model.openSettings() }
    @objc private func pasteLink() { showWindow(); model.paste() }
    @objc private func openRelay() { showWindow() }
    @objc private func quitRelay() { NSApplication.shared.terminate(nil) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(settings) || menuItem.action == #selector(quitRelay) {
            return !model.sending
        }
        return true
    }

    private func buildStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(named: "BrandMark")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.toolTip = "NZBPort"
            button.setAccessibilityLabel("NZBPort")
        }

        let menu = NSMenu()
        for (title, action) in [
            ("NZBPort öffnen", #selector(openRelay)),
            ("NZBlnk aus Zwischenablage", #selector(pasteLink)),
            ("Einstellungen …", #selector(settings))
        ] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        menu.addItem(appearanceMenu.makeItem())
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "NZBPort beenden", action: #selector(quitRelay), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "Einstellungen …", action: #selector(settings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(appearanceMenu.makeItem())
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "NZBPort beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let file = NSMenuItem()
        menu.addItem(file)
        let fileMenu = NSMenu(title: "Ablage")
        let paste = NSMenuItem(title: "NZBlnk aus Zwischenablage", action: #selector(pasteLink), keyEquivalent: "v")
        paste.keyEquivalentModifierMask = [.command, .shift]
        paste.target = self
        fileMenu.addItem(paste)
        fileMenu.addItem(withTitle: "Fenster schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        file.submenu = fileMenu

        let edit = NSMenuItem()
        menu.addItem(edit)
        let editMenu = NSMenu(title: "Bearbeiten")
        editMenu.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        for (title, selector, key) in [("Ausschneiden", "cut:", "x"), ("Kopieren", "copy:", "c"), ("Einsetzen", "paste:", "v"), ("Alles auswählen", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        edit.submenu = editMenu
        NSApplication.shared.mainMenu = menu
    }
}

@main
enum NZBRelayMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
