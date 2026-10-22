import SwiftUI
import RelayCore

struct DownloadView: View {
    @Bindable var model: AppModel
    @Environment(\.colorTheme) private var colorTheme
    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            if let link = model.current {
                VStack(alignment: .leading, spacing: 12) {
                    Label(L("Bereit für SABnzbd"), systemImage: "link")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text(link.title).font(RelayTheme.downloadTitleFont)
                        .lineLimit(4).textSelection(.enabled)
                    if link.password != nil {
                        Label(L("Entpackpasswort enthalten"), systemImage: "lock")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Picker(L("Priorität"), selection: $model.selectedPriority) {
                    ForEach(SABPriority.allCases) { priority in Text(priority.title).tag(priority) }
                }.disabled(model.busy || model.addPaused)
                Toggle(L("Pausiert hinzufügen"), isOn: $model.addPaused).disabled(model.busy)
                Divider()
                HStack {
                    Text(L("Kategorie wählen")).font(.headline)
                    Spacer()
                    Button { model.loadCategories() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonBorderShape(.circle).help(L("Kategorien aktualisieren")).disabled(model.busy)
                }
                if model.busy { BusyRow(text: L(model.progress)) }
                if !model.categories.isEmpty {
                    SearchField(text: $model.query)
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 8) {
                            ForEach(model.visibleCategories, id: \.self) { category in
                                CategorySendButton(name: model.categoryName(category)) { model.send(category: category) }
                                    .disabled(model.busy)
                            }
                        }
                    }
                    if model.visibleCategories.isEmpty {
                        Text(model.query.isEmpty ? L("Alle Kategorien sind ausgeblendet. Du kannst sie in den Einstellungen wieder einblenden.") : L("Keine passende Kategorie."))
                            .foregroundStyle(.secondary)
                    }
                }
                Button(L("Link verwerfen")) { model.discardCurrent() }
                    .foregroundStyle(.secondary).disabled(model.sending)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 36, weight: .light)).foregroundStyle(colorTheme.accent)
                        .accessibilityHidden(true)
                    Text(L("Bereit für deinen Link"))
                        .font(RelayTheme.welcomeFont)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("Öffne einen NZBlnk-Link in Safari. Hier wählst du die Kategorie für SABnzbd."))
                        .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(3)
                    Button { model.chooseFiles() } label: {
                        Label(L("NZB-Dateien öffnen …"), systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .relayPrimaryAction().controlSize(.large)
                    .disabled(model.busy)
                    Button { model.paste() } label: {
                        Label(L("NZBlnk aus Zwischenablage"), systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .relayPrimaryAction().controlSize(.large)
                    .disabled(model.busy)
                }
                Divider()
                HStack {
                    Image(systemName: "safari").font(.system(size: 24)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Direkt aus Safari")).font(.headline)
                        Text(L("NZBPort als App für NZBlnk-Links festlegen."))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button(model.handlerRegistered ? L("Als Link-App eingerichtet") : L("Als Link-App verwenden")) { model.registerHandler() }
                    .disabled(model.busy || model.handlerRegistered || model.registeringHandler)
                Text(L("NZB-Dateien und Links kannst du auch in dieses Fenster ziehen."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("Falls eine Browser-Erweiterung den Klick abfängt, deaktiviere deren Link-Verarbeitung in Safari."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
