import SwiftUI
import RelayCore

struct ConnectionSettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Deine Verbindung").font(RelayTheme.pageTitleFont)
                Text("NZBPort sendet direkt an deinen SABnzbd-Server.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            if let link = model.current {
                Label {
                    Text("Wartet auf die Einrichtung: \(link.title)").lineLimit(2)
                } icon: { Image(systemName: "link") }
                .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("SABnzbd-Adresse").font(.system(size: 12, weight: .medium))
                TextField("http://localhost:8080/api", text: $model.address)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
                    .autocorrectionDisabled()
                Text("Beispiel: http://localhost:8080/api oder die Adresse deines NAS.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("API-Key").font(.system(size: 12, weight: .medium))
                SecureField("Vollständiger SABnzbd-API-Key", text: $model.key)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
                Text("Wird lokal und unverschlüsselt in den App-Einstellungen gespeichert.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            GlassEffectContainer(spacing: 16) {
                HStack {
                    Button("Verbindung prüfen") { model.loadCategories() }
                        .disabled(model.busy)
                    Spacer()
                    Button("Speichern") { model.save() }
                        .relayPrimaryAction().disabled(model.busy)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            if model.busy { BusyRow(text: model.progress) }
            else if !model.categories.isEmpty {
                Label("\(model.categories.count) Kategorien von SABnzbd geladen", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12)).foregroundStyle(.green)
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Deine Kategorien").font(.headline)
                    Spacer()
                    Button { model.loadCategories() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonBorderShape(.circle).help("Kategorien aktualisieren").disabled(model.busy)
                }
                Text("Ausgeblendete Kategorien bleiben in SABnzbd erhalten. Neue Kategorien erscheinen automatisch.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(model.preferences.visible(in: model.categories), id: \.self) { category in
                    CategoryPreferenceRow(name: model.categoryName(category), hidden: false) { model.setVisible(false, category: category) }
                }
                if model.categories.isEmpty {
                    Text("Prüfe die Verbindung, um deine Kategorien zu laden.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                }
            }
            if !model.hiddenCategories.isEmpty {
                Text("Ausgeblendet").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(model.hiddenCategories, id: \.self) { category in
                        CategoryPreferenceRow(name: model.categoryName(category), hidden: true) { model.setVisible(true, category: category) }
                    }
                }
            }
        }
        .disabled(model.sending)
    }
}
