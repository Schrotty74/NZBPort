import RelayCore
import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, NSMenuDelegate {
    let model = AppModel()
    private var window: NSWindow?
    private var contentOverflow: CGFloat = 0
    private var resizedByUser = false
    private var statusItem: NSStatusItem?
    private var statusSummary: NSMenuItem?
    private var statusMenuSession: UUID?
    private let aboutMenu = AboutMenu()
    private lazy var loginItemMenu = LoginItemMenu(settings: model.loginItemSettings)
    private lazy var languageMenu = LanguageMenu(settings: model.languageSettings)
    private lazy var appearanceMenu = AppearanceMenu(settings: model.appearanceSettings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = launchEvent?.eventID == kAEOpenApplication &&
            launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        buildMenu()
        buildStatusMenu()
        model.appearanceSettings.onModeChange = { [weak self] in
            guard let self else { return }
            self.window?.appearance = self.model.appearanceSettings.mode.native
            self.window?.backgroundColor = self.model.appearanceSettings.theme.windowColor
        }
        model.languageSettings.onChange = { [weak self] in
            self?.buildMenu()
            self?.buildStatusMenu()
        }
        model.loginItemSettings.onError = { [weak self] error in
            self?.model.notice = Notice(text: "Autostart konnte nicht geändert werden: \(error.localizedDescription)", isError: true)
            self?.showWindow()
        }
        model.monitor.installNotificationDelegate()
        model.refreshHandlerRegistration()
        Task { await model.refreshCategoriesAtStartup() }
        if !launchedAtLogin { showWindow() }
        model.closeAfterSuccess = { [weak self] in self?.window?.close() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshHandlerRegistration()
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
            let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
            var contentSize = RelayTheme.windowSize
            if let visibleFrame = NSScreen.main?.visibleFrame {
                let availableHeight = NSWindow.contentRect(forFrameRect: visibleFrame, styleMask: style).height
                contentSize.height = min(contentSize.height, availableHeight)
            }
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: contentSize),
                                  styleMask: style, backing: .buffered, defer: false)
            window.title = "NZBPort"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.isOpaque = false
            window.backgroundColor = model.appearanceSettings.theme.windowColor
            window.appearance = model.appearanceSettings.mode.native
            window.isReleasedWhenClosed = false
            window.minSize = RelayTheme.minimumWindowSize
            window.contentView = NSHostingView(rootView: RelayRootView(model: model) { [weak self] overflow in
                self?.contentOverflow = overflow
                self?.fitWindowToContent()
            })
            window.delegate = self
            window.center()
            self.window = window
        }
        model.monitor.setVisible(model.screen == .overview)
        window?.makeKeyAndOrderFront(nil)
        fitWindowToContent()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func fitWindowToContent() {
        guard !resizedByUser, contentOverflow > 0,
              let window, window.isVisible, !window.isMiniaturized, !window.styleMask.contains(.fullScreen),
              let visibleFrame = window.screen?.visibleFrame else { return }
        var frame = window.frame
        let growth = min(contentOverflow, visibleFrame.height - frame.height)
        guard growth >= 1 else { return }
        frame.size.height += growth
        frame.origin.y = min(max(frame.origin.y - growth, visibleFrame.minY), visibleFrame.maxY - frame.height)
        // Wait for the next measurement before applying another resize.
        contentOverflow = 0
        window.setFrame(frame, display: true)
    }

    func windowWillStartLiveResize(_ notification: Notification) { resizedByUser = true }

    func windowWillClose(_ notification: Notification) {
        resizedByUser = false
        model.monitor.setVisible(false)
    }
    @objc private func openFiles() { showWindow(); model.chooseFiles() }
    @objc private func openSAB() { model.openSABnzbd() }
    @objc private func overview() { model.screen = .overview; showWindow() }
    @objc private func updates() {
        model.screen = .updates
        showWindow()
        Task { await model.updateSettings.check() }
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
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(named: "BrandMark")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.toolTip = "NZBPort"
            button.setAccessibilityLabel("NZBPort")
        }

        let menu = NSMenu()
        menu.delegate = self
        let summary = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())
        statusSummary = summary
        for (title, action) in [
            (L("NZBPort öffnen"), #selector(openRelay)),
            (L("NZBlnk aus Zwischenablage"), #selector(pasteLink)),
            (L("Einstellungen …"), #selector(settings)),
            (L("NZB-Dateien öffnen …"), #selector(openFiles)),
            (L("SABnzbd im Browser öffnen"), #selector(openSAB)),
            (L("Downloads"), #selector(overview)),
            (L("Nach Updates suchen …"), #selector(updates))
        ] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        menu.addItem(appearanceMenu.makeItem())
        menu.addItem(languageMenu.makeItem())
        menu.addItem(loginItemMenu.makeItem())
        menu.addItem(aboutMenu.makeItem())
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("NZBPort beenden"), action: #selector(quitRelay), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        let session = UUID()
        statusMenuSession = session
        observeStatusSummary(session: session)
        Task { await model.monitor.refresh() }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusMenuSession = nil
    }

    private func observeStatusSummary(session: UUID) {
        guard statusMenuSession == session else { return }
        let title = withObservationTracking {
            downloadStatusTitle
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeStatusSummary(session: session) }
        }
        statusSummary?.title = title
    }

    private var downloadStatusTitle: String {
        let monitor = model.monitor
        guard model.configured else { return L("SABnzbd nicht eingerichtet") }
        if monitor.statusUnavailable { return L("SABnzbd-Status nicht verfügbar") }
        guard let queue = monitor.queue else { return L("SABnzbd-Status wird geladen …") }
        if queue.paused { return L("SABnzbd-Warteschlange pausiert") }
        if queue.jobs.isEmpty { return L("Keine aktiven Downloads.") }
        let summary = L("In der Warteschlange: \(queue.jobs.count)")
        return queue.speed.isEmpty ? summary : "\(summary) · \(queue.speed)B/s"
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        let settings = NSMenuItem(title: L("Einstellungen …"), action: #selector(settings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(appearanceMenu.makeItem())
        appMenu.addItem(languageMenu.makeItem())
        appMenu.addItem(loginItemMenu.makeItem())
        appMenu.addItem(aboutMenu.makeItem())
        let updateItem = NSMenuItem(title: L("Nach Updates suchen …"), action: #selector(updates), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(updateItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("NZBPort beenden"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let file = NSMenuItem()
        menu.addItem(file)
        let fileMenu = NSMenu(title: L("Ablage"))
        for (title, action) in [(L("NZB-Dateien öffnen …"), #selector(openFiles)), (L("Downloads"), #selector(overview)), (L("SABnzbd im Browser öffnen"), #selector(openSAB))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            fileMenu.addItem(entry)
        }
        let paste = NSMenuItem(title: L("NZBlnk aus Zwischenablage"), action: #selector(pasteLink), keyEquivalent: "v")
        paste.keyEquivalentModifierMask = [.command, .shift]
        paste.target = self
        fileMenu.addItem(paste)
        fileMenu.addItem(withTitle: L("Fenster schließen"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        file.submenu = fileMenu

        let edit = NSMenuItem()
        menu.addItem(edit)
        let editMenu = NSMenu(title: L("Bearbeiten"))
        editMenu.addItem(withTitle: L("Widerrufen"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        for (title, selector, key) in [(L("Ausschneiden"), "cut:", "x"), (L("Kopieren"), "copy:", "c"), (L("Einsetzen"), "paste:", "v"), (L("Alles auswählen"), "selectAll:", "a")] {
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
