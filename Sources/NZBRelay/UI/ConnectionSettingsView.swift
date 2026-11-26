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
                Button(L("Verbindung prüfen")) { model.checkConnection() }
                    .disabled(model.connectionStatus == .checking)
                ConnectionStatusView(status: model.connectionStatus)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        } label: {
            Label("SABnzbd", systemImage: "server.rack").font(.headline)
        }
    }
}

struct ConnectionStatusView: View {
    let status: SABConnectionStatus

    var body: some View {
        switch status {
        case .unchecked:
            Label(L("Verbindung nicht geprüft."), systemImage: "minus.circle")
                .foregroundStyle(.secondary).font(.caption)
        case .checking:
            BusyRow(text: L("SABnzbd-Verbindung wird geprüft …"))
        case .connected(let count):
            Label {
                Text(L("SABnzbd verbunden · \(count) Kategorien"))
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .font(.caption)
        case .failed(let message):
            Label {
                Text(L("SABnzbd-Verbindung nicht bestätigt. \(message)"))
            } icon: {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct IndexerSettingsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("NZBPort sucht von oben nach unten. Deaktivierte Suchdienste und Dienste ohne erforderlichen API-Key werden übersprungen."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                ForEach(model.indexerPreferences.order, id: \.self) { indexer in
                    if indexer != model.indexerPreferences.order.first { Divider() }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle(indexer.rawValue, isOn: Binding(
                                get: { !model.indexerPreferences.disabled.contains(indexer) },
                                set: { model.indexerPreferences.setEnabled($0, for: indexer) }
                            ))
                            Spacer()
                            Button(L("\(indexer.rawValue) nach oben"), systemImage: "arrow.up") {
                                model.indexerPreferences.move(indexer, by: -1)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(indexer == model.indexerPreferences.order.first)
                            Button(L("\(indexer.rawValue) nach unten"), systemImage: "arrow.down") {
                                model.indexerPreferences.move(indexer, by: 1)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(indexer == model.indexerPreferences.order.last)
                        }
                        if let key = apiKey(for: indexer) {
                            SecureField(L("API-Key"), text: key)
                                .textFieldStyle(.roundedBorder).controlSize(.large)
                                .accessibilityLabel("\(indexer.rawValue) API-Key")
                        }
                    }
                }
                Text(L("Die API-Keys werden lokal und unverschlüsselt gespeichert."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        } label: {
            Label(L("Suchdienste"), systemImage: "magnifyingglass").font(.headline)
        }
    }
    private func apiKey(for indexer: IndexerPreferences.Indexer) -> Binding<String>? {
        switch indexer {
        case .nzbIndex, .nzbKing, .binSearch: nil
        case .treasureMaps: $model.treasureMapsKey
        case .newzBay: $model.newzBayKey
        case .ninjaCentral: $model.ninjaCentralKey
        case .drunkenSlug: $model.drunkenSlugKey
        case .nzbFinder: $model.nzbFinderKey
        case .videothek: $model.videothekKey
        }
    }
}
