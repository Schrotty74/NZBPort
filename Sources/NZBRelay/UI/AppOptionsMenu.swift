import SwiftUI

struct AppOptionsMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        @Bindable var appearance = model.appearanceSettings
        Menu("App-Menü", systemImage: "gearshape") {
            Button("Verbindungseinstellungen …", systemImage: "network") {
                model.openSettings()
            }
            .disabled(model.sending || model.screen == .settings)
            Menu("Erscheinungsbild", systemImage: "circle.lefthalf.filled") {
                Picker("Farbschema", selection: $appearance.mode) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Picker("Fensterhintergrund", selection: $appearance.background) {
                    ForEach(BackgroundStyle.allCases) { background in
                        Text(background.title).tag(background)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .glassEffect(.regular, in: .circle)
        .help("App-Menü öffnen")
        .accessibilityLabel("App-Menü öffnen")
    }
}
