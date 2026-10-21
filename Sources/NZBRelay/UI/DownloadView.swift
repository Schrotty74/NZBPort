import SwiftUI
import RelayCore

struct DownloadView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            if let link = model.current {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Bereit für SABnzbd", systemImage: "link")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text(link.title).font(RelayTheme.downloadTitleFont)
                        .lineLimit(4).textSelection(.enabled)
                    if link.password != nil {
                        Label("Entpackpasswort enthalten", systemImage: "lock")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack {
                    Text("Kategorie wählen").font(.headline)
                    Spacer()
                    Button { model.loadCategories() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonBorderShape(.circle).help("Kategorien aktualisieren").disabled(model.busy)
                }
                if model.busy { BusyRow(text: model.progress) }
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
                        Text(model.query.isEmpty ? "Alle Kategorien sind ausgeblendet. Du kannst sie in den Einstellungen wieder einblenden." : "Keine passende Kategorie.")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Link verwerfen") { model.discardCurrent() }
                    .foregroundStyle(.secondary).disabled(model.sending)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 36, weight: .light)).foregroundStyle(RelayTheme.accent)
                        .accessibilityHidden(true)
                    Text("Bereit für deinen Link")
                        .font(RelayTheme.welcomeFont)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Öffne einen NZBlnk-Link in Safari. Hier wählst du die Kategorie für SABnzbd.")
                        .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(3)
                    Button { model.paste() } label: {
                        Label("NZBlnk aus Zwischenablage", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .relayPrimaryAction().controlSize(.large)
                    .padding(.top, 6)
                }
                Divider()
                HStack {
                    Image(systemName: "safari").font(.system(size: 24)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Direkt aus Safari").font(.headline)
                        Text("NZBPort als App für NZBlnk-Links festlegen.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button(model.handlerRegistered ? "Als Link-App eingerichtet" : "Als Link-App verwenden") { model.registerHandler() }
                    .disabled(model.busy || model.handlerRegistered || model.registeringHandler)
                Text("Falls eine Browser-Erweiterung den Klick abfängt, deaktiviere deren Link-Verarbeitung in Safari.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
