import SwiftUI
import RelayCore

struct CategoriesView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            HStack {
                Text(L("Deine Kategorien")).font(RelayTheme.pageTitleFont)
                Spacer()
                Button { model.loadCategories() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonBorderShape(.circle).help(L("Kategorien aktualisieren"))
                    .disabled(model.busy || !model.configured)
            }
            if !model.configured {
                Text(L("Richte zuerst die Verbindung zu SABnzbd ein, um Kategorien zu verwalten."))
                    .foregroundStyle(.secondary)
                Button(L("Verbindungseinstellungen …")) { model.openSettings() }
            } else {
                Text(L("Hinzufügen und Löschen ändern die Kategorien in SABnzbd. Favoriten und Ausblendungen gelten nur für NZBPort."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(L("Name der Kategorie"), text: $model.newCategoryName)
                            .textFieldStyle(.roundedBorder).controlSize(.large)
                            .autocorrectionDisabled()
                        Button(L("In SABnzbd hinzufügen")) { model.addCategory() }
                            .relayPrimaryAction()
                            .disabled(model.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                } label: {
                    Label(L("Neue Kategorie"), systemImage: "folder.badge.plus").font(.headline)
                }
                .disabled(model.busy)
                if model.busy { BusyRow(text: L(model.progress)) }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L("Sterne heften Favoriten oben an. Mit den Pfeilen änderst du ihre Reihenfolge."))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(L("Ausgeblendete Kategorien bleiben in SABnzbd erhalten. Neue Kategorien erscheinen automatisch."))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 0) {
                            ForEach(model.preferences.visible(in: model.categories), id: \.self) { category in
                                VStack(spacing: 0) {
                                    HStack {
                                        Button { model.setFavorite(!model.preferences.isFavorite(category), category: category) } label: {
                                            Image(systemName: model.preferences.isFavorite(category) ? "star.fill" : "star")
                                        }.help(L("Favorit umschalten"))
                                        CategoryPreferenceRow(
                                            name: model.categoryName(category), hidden: false,
                                            action: { model.setVisible(false, category: category) },
                                            deleteAction: model.canDeleteCategory(category) ? { model.requestCategoryDeletion(category) } : nil
                                        )
                                    }
                                    if model.preferences.isFavorite(category) {
                                        HStack {
                                            Spacer()
                                            Button(L("Nach oben"), systemImage: "arrow.up") { model.moveFavorite(category, by: -1) }
                                            Button(L("Nach unten"), systemImage: "arrow.down") { model.moveFavorite(category, by: 1) }
                                        }.controlSize(.mini).padding(.bottom, 8)
                                    }
                                }
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
                                    CategoryPreferenceRow(
                                        name: model.categoryName(category), hidden: true,
                                        action: { model.setVisible(true, category: category) },
                                        deleteAction: model.canDeleteCategory(category) ? { model.requestCategoryDeletion(category) } : nil
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label(L("Vorhandene Kategorien"), systemImage: "folder").font(.headline)
                }
                .disabled(model.busy)
            }
        }
        .disabled(model.sending)
    }
}
