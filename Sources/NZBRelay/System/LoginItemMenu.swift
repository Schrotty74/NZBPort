import AppKit

@MainActor
final class LoginItemMenu: NSObject, NSMenuDelegate {
    private let settings: LoginItemSettings

    init(settings: LoginItemSettings) { self.settings = settings }

    func makeItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("Autostart"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L("Autostart"))
        menu.delegate = self
        let toggle = NSMenuItem(title: L("Beim Anmelden starten"), action: #selector(toggleStartup), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let approval = NSMenuItem(title: L("In macOS erlauben …"), action: #selector(openSettings), keyEquivalent: "")
        approval.target = self
        menu.addItem(approval)
        item.submenu = menu
        menuNeedsUpdate(menu)
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        settings.refresh()
        for item in menu.items {
            if item.action == #selector(toggleStartup) {
                item.state = settings.needsApproval ? .mixed : (settings.requested ? .on : .off)
                item.isEnabled = !settings.changing
            } else if item.action == #selector(openSettings) {
                item.isHidden = !settings.needsApproval
            }
        }
    }

    @objc private func toggleStartup() { settings.setEnabled(!settings.requested) }
    @objc private func openSettings() { settings.openSystemSettings() }
}
