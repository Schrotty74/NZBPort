import SwiftUI
import RelayCore



struct CategoriesView: View {
    @Bindable var model: AppModel
    @State private var draggedFavorite: String?
    @State private var dragOffset: CGFloat = 0
    @State private var favoriteRowHeight: CGFloat = 55

    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            HStack {
                Text(L("Deine Kategorien")).font(RelayTheme.pageTitleFont)
                Spacer()
                Button { model.loadCategories() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonBorderShape(.circle)
                    .relayInteractiveRoundControl()
                    .help(L("Kategorien aktualisieren"))
                    .disabled(model.busy || !model.configured)
            }
            if !model.configured {
                Text(L("Richte zuerst die Verbindung zu SABnzbd ein, um Kategorien zu verwalten."))
                    .foregroundStyle(.secondary)
                Button(L("Verbindungseinstellungen …")) { model.openSettings() }
            } else {
                Text(L("Hinzufügen und Löschen ändern die Kategorien in SABnzbd. Favoriten und Ausblendungen gelten nur für NZBPort."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                CategoryRecognitionView(
                    recognition: $model.categoryRecognition,
                    categories: model.preferences.visible(in: model.categories),
                    categoryName: model.categoryName
                )
                .disabled(model.busy)
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
                            Text(L(availableReorderInstructions))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(L("Ausgeblendete Kategorien bleiben in SABnzbd erhalten. Neue Kategorien erscheinen automatisch."))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        visibleCategoryRows
                        if model.categories.isEmpty {
                            Text(L("Prüfe die Verbindung, um deine Kategorien zu laden."))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
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

    private var favoriteCategories: [String] {
        model.preferences.visible(in: model.categories).filter { model.preferences.isFavorite($0) }
    }

    private var availableReorderInstructions: String.LocalizationValue {
        if #available(macOS 27, *) {
            return "Sterne heften Favoriten oben an. Ziehe sie zum Sortieren oder nutze die Pfeile."
        }
        return "Sterne heften Favoriten oben an. Mit den Pfeilen änderst du ihre Reihenfolge."
    }

    private var ordinaryCategories: [String] {
        model.preferences.visible(in: model.categories).filter { !model.preferences.isFavorite($0) }
    }

    @ViewBuilder
    private var visibleCategoryRows: some View {
        if #available(macOS 27, *) {
            VStack(spacing: 0) {
                ForEach(favoriteCategories, id: \.self) { category in
                    favoriteRow(category)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, height in
                            if height > 0 { favoriteRowHeight = height }
                        }
                        .offset(y: draggedFavorite == category ? dragOffset : 0)
                        .zIndex(draggedFavorite == category ? 1 : 0)
                        .highPriorityGesture(DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                draggedFavorite = category
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                defer { draggedFavorite = nil; dragOffset = 0 }
                                let favorites = favoriteCategories
                                guard let from = favorites.firstIndex(of: category) else { return }
                                let steps = Int((value.translation.height / favoriteRowHeight).rounded())
                                let to = min(max(from + steps, 0), favorites.count - 1)
                                guard from != to else { return }
                                let destination = from < to ? (to + 1 < favorites.count ? favorites[to + 1] : nil) : favorites[to]
                                model.reorderFavorites(favorites, moving: [category], before: destination)
                            })
                }
            }
            ordinaryCategoryRows
        } else {
            VStack(spacing: 0) {
                ForEach(favoriteCategories, id: \.self) { category in
                    favoriteRow(category)
                }
                ordinaryCategoryRows
            }
        }
    }

    private var ordinaryCategoryRows: some View {
        ForEach(ordinaryCategories, id: \.self) { category in
            categoryRow(category, isFavorite: false)
        }
    }

    private func favoriteRow(_ category: String) -> some View {
        VStack(spacing: 0) {
            categoryRow(category, isFavorite: true)
            HStack {
                Spacer()
                Button(L("Nach oben"), systemImage: "arrow.up") { model.moveFavorite(category, by: -1) }
                Button(L("Nach unten"), systemImage: "arrow.down") { model.moveFavorite(category, by: 1) }
            }
            .controlSize(.mini).padding(.bottom, 8)
        }
        .contentShape(.rect)
    }

    private func categoryRow(_ category: String, isFavorite: Bool) -> some View {
        HStack {
            Button { model.setFavorite(!isFavorite, category: category) } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .help(L("Favorit umschalten"))
            CategoryPreferenceRow(
                name: model.categoryName(category), hidden: false,
                action: { model.setVisible(false, category: category) },
                deleteAction: model.canDeleteCategory(category) ? { model.requestCategoryDeletion(category) } : nil
            )
        }
    }
}
