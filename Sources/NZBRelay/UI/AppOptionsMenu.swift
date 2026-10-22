import RelayCore
import SwiftUI

struct AppOptionsMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        @Bindable var appearance = model.appearanceSettings
        @Bindable var language = model.languageSettings
        let login = model.loginItemSettings
        Menu(L("App-Menü"), systemImage: "gearshape") {
            Button(L("Verbindungseinstellungen …"), systemImage: "network") {
                model.openSettings()
            }
            .disabled(model.sending || model.screen == .settings)
            Button(L("NZB-Dateien öffnen …"), systemImage: "doc.badge.plus") { model.chooseFiles() }
            Button(L("SABnzbd im Browser öffnen"), systemImage: "safari") { model.openSABnzbd() }.disabled(!model.configured)
            Button(L("Downloads"), systemImage: "arrow.down.circle") { model.screen = .overview }
            Button(L("Nach Updates suchen …"), systemImage: "arrow.triangle.2.circlepath") {
                model.screen = .updates
                Task { await model.updateSettings.check() }
            }
            Divider()
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
            Divider()
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
            Menu(L("Über NZBPort"), systemImage: "info.circle") {
                Link("GitHub", destination: AppLinks.github)
                Link(L("Homepage"), destination: AppLinks.homepage)
            }
        }
        .onAppear { login.refresh() }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .glassEffect(.regular, in: .circle)
        .help(L("App-Menü öffnen"))
        .accessibilityLabel(L("App-Menü öffnen"))
    }
}
