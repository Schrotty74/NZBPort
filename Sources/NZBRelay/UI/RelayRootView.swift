import SwiftUI
import UniformTypeIdentifiers
import RelayCore

struct RelayRootView: View {
    @Bindable var model: AppModel
    @State private var dropTargeted = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: "BrandMark") ?? NSImage(size: .zero))
                    .resizable().renderingMode(.template).scaledToFit()
                    .frame(width: 29, height: 29)
                    .foregroundStyle(model.appearanceSettings.theme.accent)
                    .accessibilityHidden(true)
                Text("NZBPort").font(RelayTheme.brandFont)
                Spacer()
                if model.screen != .downloads && (model.configured || model.screen != .settings) {
                    Button { model.screen = model.configured ? .downloads : .settings; model.notice = nil } label: {
                        Label(L("Zurück"), systemImage: "arrow.left")
                    }
                    .disabled(model.busy)
                }
                AppOptionsMenu(model: model)
            }
            .padding(.horizontal, RelayTheme.pagePadding).padding(.vertical, 12)
            Divider()
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
                        if let notice = model.notice { NoticeView(notice: notice).id("relayNotice") }
                        if model.screen == .settings { ConnectionSettingsView(model: model) }
                        else if model.screen == .overview { DownloadOverview(model: model) }
                        else if model.screen == .updates { UpdateView(settings: model.updateSettings) }
                        else { DownloadView(model: model) }
                    }
                    .padding(RelayTheme.pagePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: model.notice) { _, notice in
                    if notice != nil { reader.scrollTo("relayNotice", anchor: .top) }
                }
            }
            Divider()
            HStack(spacing: 7) {
                Circle().fill(model.configured ? Color.green : Color.secondary).frame(width: 6, height: 6)
                Text(model.configured ? model.serverHost : L("Verbindung einrichten"))
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if !model.pending.isEmpty { Text(L("\(model.pending.count) weitere Links")) }
                else { Text(L("Für deinen Mac")) }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, RelayTheme.pagePadding).padding(.vertical, 9)
        }
        .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 12).stroke(model.appearanceSettings.theme.accent, lineWidth: 3).allowsHitTesting(false) } }
        .onDrop(of: [.fileURL, .url], isTargeted: $dropTargeted) { providers in
            for provider in providers {
                let type = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ? UTType.fileURL.identifier : UTType.url.identifier
                provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let value = item as? URL { url = value }
                    else if let value = item as? String { url = URL(string: value) }
                    else { url = nil }
                    if let url { Task { @MainActor in model.receive([url]) } }
                }
            }
            return !providers.isEmpty
        }
        .confirmationDialog(L("Diesen Auftrag erneut senden?"), isPresented: Binding(
            get: { model.duplicateCategory != nil }, set: { if !$0 { model.duplicateCategory = nil } }
        ), titleVisibility: .visible) {
            Button(L("Trotzdem senden")) { model.confirmDuplicate() }
            Button(L("Abbrechen"), role: .cancel) { model.duplicateCategory = nil }
        } message: {
            Text(L("Dieser Auftrag wurde in den letzten zehn Minuten bereits übergeben oder versucht. Prüfe nach einem Verbindungsfehler zuerst die SABnzbd-Warteschlange."))
        }
        .onChange(of: model.screen) { _, screen in model.monitor.setVisible(screen == .overview) }
        .onAppear { model.monitor.setVisible(model.screen == .overview) }
        .onDisappear { model.monitor.setVisible(false) }
        .id(model.languageSettings.effectiveLanguage)
        .environment(\.locale, Localization.locale)
        .environment(\.colorTheme, model.appearanceSettings.theme)
        .tint(model.appearanceSettings.theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            model.languageSettings.refreshSystemLanguage()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.loginItemSettings.refresh()
        }
        .frame(minWidth: RelayTheme.minimumWindowSize.width,
               minHeight: RelayTheme.minimumWindowSize.height - 28)
        .background { RelayBackground(style: model.appearanceSettings.background) }
        .preferredColorScheme(model.appearanceSettings.mode.colorScheme)
        .relayGlassControls()
    }
}
