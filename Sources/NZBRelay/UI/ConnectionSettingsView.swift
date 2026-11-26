import SwiftUI
import RelayCore

struct ConnectionSettingsView: View {
    @Bindable var model: AppModel
    @State private var pane = Pane.sabnzbd

    private enum Pane: Hashable { case sabnzbd, indexers }

    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            Text(L("Deine Verbindung")).font(RelayTheme.pageTitleFont)
            Picker(L("Verbindung"), selection: $pane) {
                Text("SABnzbd").tag(Pane.sabnzbd)
                Text(L("Suchdienste")).tag(Pane.indexers)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let link = model.current {
                Label {
                    Text(L("Wartet auf die Einrichtung: \(link.title)")).lineLimit(2)
                } icon: { Image(systemName: "link") }
                .font(.system(size: 12)).foregroundStyle(.secondary)
                SaveNZBButton(model: model)
            }

            switch pane {
            case .sabnzbd: SABConnectionSection(model: model)
            case .indexers: IndexerSettingsSection(model: model)
            }
        }
        .disabled(model.sending)
    }
}

struct SABConnectionSection: View {
    @Bindable var model: AppModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("SABnzbd-Adresse")).font(.system(size: 12, weight: .medium))
                    TextField("http://localhost:8080/api", text: $model.address)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .accessibilityLabel(L("SABnzbd-Adresse"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("API-Key")).font(.system(size: 12, weight: .medium))
                    SecureField(L("Vollständiger SABnzbd-API-Key"), text: $model.key)
                        .textFieldStyle(.roundedBorder)
                }
                Text(L("Die Zugangsdaten werden lokal und unverschlüsselt gespeichert."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Button(L("Verbindung prüfen")) { model.checkConnection() }
                        .disabled(model.connectionStatus == .checking)
                    ConnectionStatusView(status: model.connectionStatus)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
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
    @State private var selectedIndexer: IndexerPreferences.Indexer?
    @State private var expandedIndexer: IndexerPreferences.Indexer?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("NZBPort sucht von oben nach unten. Deaktivierte Suchdienste und Dienste ohne erforderliche Zugangsdaten werden übersprungen."))
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(model.indexerPreferences.order) { indexer in
                    if indexer != model.indexerPreferences.order.first { Divider() }
                    HStack(spacing: 6) {
                        Toggle(indexer.rawValue, isOn: Binding(
                            get: { !model.indexerPreferences.disabled.contains(indexer) },
                            set: { model.indexerPreferences.setEnabled($0, for: indexer) }
                        ))
                        Spacer(minLength: 8)
                        if indexer == .easynews || apiKey(for: indexer) != nil {
                            Button {
                                expandedIndexer = expandedIndexer == indexer ? nil : indexer
                            } label: {
                                Label(L("Zugangsdaten für \(indexer.rawValue)"),
                                      systemImage: expandedIndexer == indexer ? "key.fill" : "key")
                            }
                            .labelStyle(.iconOnly)
                            .help(L("Zugangsdaten für \(indexer.rawValue)"))
                            .accessibilityValue(expandedIndexer == indexer ? L("Geöffnet") : L("Geschlossen"))
                        }
                        Button(L("Testen")) { selectedIndexer = indexer }
                            .disabled(!canTest(indexer))
                            .accessibilityLabel(L("\(indexer.rawValue) testen"))
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
                    .controlSize(.small)

                    if expandedIndexer == indexer {
                        VStack(alignment: .leading, spacing: 6) {
                            if indexer == .easynews {
                                TextField(L("Easynews-Benutzername"), text: $model.easynewsUsername)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                SecureField(L("Easynews-Passwort"), text: $model.easynewsPassword)
                                    .textFieldStyle(.roundedBorder)
                            } else if let key = apiKey(for: indexer) {
                                SecureField(L("API-Key"), text: key)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("\(indexer.rawValue) API-Key")
                            }
                            Text(L("Die Zugangsdaten werden lokal und unverschlüsselt gespeichert."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 4)
                    }
                }
                Label(L("Zugangsdaten bearbeitest du über das Schlüsselsymbol."), systemImage: "key")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .sheet(item: $selectedIndexer) { indexer in
            IndexerTestView(indexer: indexer, apiKey: apiKey(for: indexer)?.wrappedValue ?? "",
                            username: model.easynewsUsername, password: model.easynewsPassword)
        }
    }

    private func canTest(_ indexer: IndexerPreferences.Indexer) -> Bool {
        if indexer == .easynews {
            return !model.easynewsUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !model.easynewsPassword.isEmpty
        }
        guard let key = apiKey(for: indexer) else { return true }
        return !key.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func apiKey(for indexer: IndexerPreferences.Indexer) -> Binding<String>? {
        switch indexer {
        case .nzbIndex, .nzbKing, .binSearch, .easynews: nil
        case .treasureMaps: $model.treasureMapsKey
        case .newzBay: $model.newzBayKey
        case .ninjaCentral: $model.ninjaCentralKey
        case .drunkenSlug: $model.drunkenSlugKey
        case .nzbFinder: $model.nzbFinderKey
        case .videothek: $model.videothekKey
        }
    }
}
