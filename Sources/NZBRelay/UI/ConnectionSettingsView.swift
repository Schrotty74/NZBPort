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
                SaveNZBButton(model: model)
            }
            SABConnectionSection(model: model)
            IndexerSettingsSection(model: model)
            HStack {
                Spacer()
                Button(L("Speichern")) { model.save() }
                    .relayPrimaryAction().disabled(model.busy)
                    .keyboardShortcut("s", modifiers: .command)
            }
        }
        .disabled(model.sending)
    }
}

private struct SABConnectionSection: View {
    @Bindable var model: AppModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
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
                Button(L("Verbindung prüfen")) { model.loadCategories() }
                    .disabled(model.busy)
                if model.busy { BusyRow(text: L(model.progress)) }
                else if !model.categories.isEmpty {
                    Label(L("\(model.categories.count) Kategorien von SABnzbd geladen"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        } label: {
            Label("SABnzbd", systemImage: "server.rack").font(.headline)
        }
    }
}

private struct IndexerSettingsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("Nur Suchdienste mit gespeichertem API-Key werden verwendet."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                IndexerKeyField(name: "Treasure Maps", key: $model.treasureMapsKey)
                Divider()
                IndexerKeyField(name: "NewzBay", key: $model.newzBayKey)
                Divider()
                IndexerKeyField(name: "NinjaCentral", key: $model.ninjaCentralKey)
                Divider()
                IndexerKeyField(name: "DrunkenSlug", key: $model.drunkenSlugKey)
                Divider()
                IndexerKeyField(name: "NZBFinder", key: $model.nzbFinderKey)
                Text(L("Die API-Keys werden lokal und unverschlüsselt gespeichert."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        } label: {
            Label(L("Optionale Suchdienste"), systemImage: "magnifyingglass").font(.headline)
        }
    }
}

private struct IndexerKeyField: View {
    let name: String
    @Binding var key: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.system(size: 12, weight: .semibold))
            SecureField(L("API-Key"), text: $key)
                .textFieldStyle(.roundedBorder).controlSize(.large)
                .accessibilityLabel("\(name) API-Key")
        }
    }
}
