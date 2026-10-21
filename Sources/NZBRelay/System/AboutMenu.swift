import AppKit

/// Shared public destinations for native menus and the SwiftUI options menu.
enum AppLinks {
    static let github = URL(string: "https://github.com/Schrotty74/NZBPort")!
    static let homepage = URL(string: "https://schrotty74.github.io/Portfolio/")!
}

@MainActor
final class AboutMenu: NSObject {
    func makeItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("Über NZBPort"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L("Über NZBPort"))
        let github = NSMenuItem(title: "GitHub", action: #selector(openGitHub), keyEquivalent: "")
        github.target = self
        menu.addItem(github)
        let homepage = NSMenuItem(title: L("Homepage"), action: #selector(openHomepage), keyEquivalent: "")
        homepage.target = self
        menu.addItem(homepage)
        item.submenu = menu
        return item
    }

    @objc private func openGitHub() { NSWorkspace.shared.open(AppLinks.github) }
    @objc private func openHomepage() { NSWorkspace.shared.open(AppLinks.homepage) }
}
