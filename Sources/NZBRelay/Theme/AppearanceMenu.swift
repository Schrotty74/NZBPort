import RelayCore
import AppKit

/// Native appearance menu shared by the application menu and the status item.
@MainActor
final class AppearanceMenu: NSObject, NSMenuDelegate {
    private let settings: AppearanceSettings

    init(settings: AppearanceSettings) { self.settings = settings }

    func makeItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("Erscheinungsbild"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L("Erscheinungsbild"))
        menu.delegate = self
        menu.addItem(NSMenuItem.sectionHeader(title: L("Farbschema")))
        for appearance in AppAppearance.allCases {
            let entry = NSMenuItem(title: appearance.title, action: #selector(selectAppearance(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = appearance.rawValue
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem.sectionHeader(title: L("Farbthema")))
        for theme in ColorTheme.allCases {
            let entry = NSMenuItem(title: theme.title, action: #selector(selectTheme(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = theme.rawValue
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem.sectionHeader(title: L("Fensterhintergrund")))
        for background in BackgroundStyle.allCases {
            let entry = NSMenuItem(title: background.title, action: #selector(selectBackground(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = background.rawValue
            menu.addItem(entry)
        }
        item.submenu = menu
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            if item.action == #selector(selectAppearance(_:)) {
                item.state = (item.representedObject as? String) == settings.mode.rawValue ? .on : .off
            } else if item.action == #selector(selectTheme(_:)) {
                item.state = (item.representedObject as? String) == settings.theme.rawValue ? .on : .off
            } else if item.action == #selector(selectBackground(_:)) {
                item.state = (item.representedObject as? String) == settings.background.rawValue ? .on : .off
            }
        }
    }

    @objc private func selectAppearance(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let appearance = AppAppearance(rawValue: value) else { return }
        settings.mode = appearance
    }

    @objc private func selectBackground(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let background = BackgroundStyle(rawValue: value) else { return }
        settings.background = background
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let theme = ColorTheme(rawValue: value) else { return }
        settings.theme = theme
    }
}
