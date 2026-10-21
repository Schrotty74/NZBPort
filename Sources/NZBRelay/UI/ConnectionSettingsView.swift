import SwiftUI
import RelayCore

struct ConnectionSettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L("Deine Verbindung")).font(RelayTheme.pageTitleFont)
                Text(L("NZBPort sendet direkt an deinen SABnzbd-Server."))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            if let link = model.current {
                Label {
                    Text(L("Wartet auf die Einrichtung: \(link.title)")).lineLimit(2)
                } icon: { Image(systemName: "link") }
                .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L("SABnzbd-Adresse")).font(.system(size: 12, weight: .medium))
                TextField("http://localhost:8080/api", text: $model.address)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
                    .autocorrectionDisabled()
                Text(L("Beispiel: http://localhost:8080/api oder die Adresse deines NAS."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L("API-Key")).font(.system(size: 12, weight: .medium))
                SecureField(L("Vollständiger SABnzbd-API-Key"), text: $model.key)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
                Text(L("Wird lokal und unverschlüsselt in den App-Einstellungen gespeichert."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            GlassEffectContainer(spacing: 16) {
                HStack {
                    Button(L("Verbindung prüfen")) { model.loadCategories() }
                        .disabled(model.busy)
                    Spacer()
                    Button(L("Speichern")) { model.save() }
                        .relayPrimaryAction().disabled(model.busy)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            if model.busy { BusyRow(text: L(model.progress)) }
            else if !model.categories.isEmpty {
                Label(L("\(model.categories.count) Kategorien von SABnzbd geladen"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12)).foregroundStyle(.green)
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L("Deine Kategorien")).font(.headline)
                    Spacer()
                    Button { model.loadCategories() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonBorderShape(.circle).help(L("Kategorien aktualisieren")).disabled(model.busy)
                }
                Text(L("Ausgeblendete Kategorien bleiben in SABnzbd erhalten. Neue Kategorien erscheinen automatisch."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(model.preferences.visible(in: model.categories), id: \.self) { category in
                    CategoryPreferenceRow(name: model.categoryName(category), hidden: false) { model.setVisible(false, category: category) }
                }
                if model.categories.isEmpty {
                    Text(L("Prüfe die Verbindung, um deine Kategorien zu laden."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                }
            }
            if !model.hiddenCategories.isEmpty {
                Text(L("Ausgeblendet")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
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
