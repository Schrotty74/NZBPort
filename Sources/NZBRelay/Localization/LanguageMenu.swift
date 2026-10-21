import AppKit
import RelayCore

@MainActor
final class LanguageMenu: NSObject, NSMenuDelegate {
    private let settings: LanguageSettings

    init(settings: LanguageSettings) { self.settings = settings }

    func makeItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("Sprache"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L("Sprache"))
        menu.delegate = self
        for language in AppLanguage.allCases {
            let entry = NSMenuItem(title: language.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = language.rawValue
            entry.state = language == settings.selection ? .on : .off
            menu.addItem(entry)
        }
        item.submenu = menu
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            item.state = (item.representedObject as? String) == settings.selection.rawValue ? .on : .off
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let language = AppLanguage(rawValue: value) else { return }
        settings.selection = language
    }
}
