import AppKit
import RelayCore
import SwiftUI

struct AppOptionsMenu: View {
    @Bindable var model: AppModel

    @State private var anchor = OptionsMenuAnchor()

    var body: some View {
        Group {
            if #available(macOS 27.0, *) {
                Button(action: showMenu) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(InteractiveGlassMenuButtonStyle())
                .background(OptionsMenuAnchorView(anchor: anchor))
            } else {
                Menu {
                    menuContent
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .frame(width: 28, height: 28)
                .glassEffect(.regular, in: .circle)
            }
        }
        .onAppear { model.loginItemSettings.refresh() }
        .help(L("App-Menü öffnen"))
        .accessibilityLabel(L("App-Menü öffnen"))
    }

    private func showMenu() {
        guard let view = anchor.view else { return }
        let menu = makeOptionsMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: view.bounds.maxX, y: view.bounds.minY - 4), in: view)
    }

    func makeOptionsMenu() -> NSMenu {
        NSHostingMenu(rootView: menuContent)
    }

    @ViewBuilder
    private var menuContent: some View {
        Button(L("NZB-Dateien öffnen …"), systemImage: "doc.badge.plus") { model.chooseFiles() }
        Button(L("Downloads"), systemImage: "arrow.down.circle") { model.screen = .overview }
        Button(L("Kategorien …"), systemImage: "folder") { model.openCategories() }
            .disabled(model.busy || model.screen == .categories)
        Button(L("SABnzbd öffnen"), systemImage: "safari") { model.openSABnzbd() }
            .disabled(!model.configured)
        Divider()
        Menu(L("Einstellungen"), systemImage: "gearshape") { settingsMenuContent }
        Menu(L("Über NZBPort"), systemImage: "info.circle") {
            Button(L("Nach Updates suchen …"), systemImage: "arrow.triangle.2.circlepath") {
                model.screen = .updates
                Task { await model.updateSettings.check() }
            }
            Divider()
            Link("GitHub", destination: AppLinks.github)
            Link(L("Homepage"), destination: AppLinks.homepage)
        }
    }

    @ViewBuilder
    private var settingsMenuContent: some View {
        @Bindable var appearance = model.appearanceSettings
        @Bindable var language = model.languageSettings
        let login = model.loginItemSettings
        Button(L("Verbindung …"), systemImage: "network") {
            model.openSettings()
        }
        .disabled(model.sending || model.categoryMutationInProgress || model.screen == .settings)
        Menu(L("Downloadordner"), systemImage: "folder.badge.plus") {
            if let folder = model.downloadFolder.folder {
                Text(folder.lastPathComponent)
                Button(L("Überwachung beenden")) { model.downloadFolder.stop() }
            }
            Button(L("Downloadordner wählen …")) { model.downloadFolder.chooseFolder() }
        }
        Picker(L("Sprache"), selection: $language.selection) {
            ForEach(AppLanguage.allCases) { choice in
                Text(choice.title).tag(choice)
            }
        }
        Menu(L("Autostart"), systemImage: "power") {
            Toggle(L("Beim Anmelden starten"), isOn: Binding(
                get: { login.requested }, set: { login.setEnabled($0) }
            ))
            .disabled(login.changing)
            if login.needsApproval {
                Button(L("In macOS erlauben …")) { login.openSystemSettings() }
            }
        }
        Menu(L("Erscheinungsbild"), systemImage: "circle.lefthalf.filled") {
            Picker(L("Farbthema"), selection: $appearance.theme) {
                ForEach(ColorTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker(L("Farbschema"), selection: $appearance.mode) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker(L("Fensterhintergrund"), selection: $appearance.background) {
                ForEach(BackgroundStyle.allCases) { background in
                    Text(background.title).tag(background)
                }
            }
            .pickerStyle(.inline)
        }
        Divider()
        Menu(L("Sicherung"), systemImage: "externaldrive") {
            Button(L("Einstellungen exportieren …")) { model.exportSettings() }
            Button(L("Einstellungen importieren …")) { model.importSettings() }
            Divider()
            Button(L("Einstellungen zurücksetzen …"), role: .destructive) { model.resetSettings() }
        }
        .disabled(!model.canManageSettings)
    }
}

@MainActor
private final class OptionsMenuAnchor {
    weak var view: NSView?
}

private struct OptionsMenuAnchorView: NSViewRepresentable {
    let anchor: OptionsMenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = OptionsMenuAnchorNSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class OptionsMenuAnchorNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
