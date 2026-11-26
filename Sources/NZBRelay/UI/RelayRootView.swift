import SwiftUI
import UniformTypeIdentifiers
import RelayCore

struct RelayRootView: View {
    @Bindable var model: AppModel
    var fitContent: (CGFloat) -> Void
    @State private var dropTargeted = false
    @State private var measuredHeaderHeight: CGFloat?
    @State private var measuredBodyHeight: CGFloat?
    @State private var measuredFooterHeight: CGFloat?

    private func reportMeasuredHeight() {
        guard let measuredHeaderHeight, let measuredBodyHeight, let measuredFooterHeight else { return }
        fitContent(measuredHeaderHeight + measuredBodyHeight + measuredFooterHeight)
    }

    private var header: some View {
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
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, height in
            measuredHeaderHeight = height
            reportMeasuredHeight()
        }
    }

    private var scrollContent: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
                    if let notice = model.notice { NoticeView(notice: notice).id("relayNotice") }
                    if let confirmation = model.automaticSubmissionNotice {
                        SubmissionConfirmationView(notice: confirmation).id("submissionConfirmation")
                    }
                    if model.screen == .settings { ConnectionSettingsView(model: model) }
                    else if model.screen == .categories { CategoriesView(model: model) }
                    else if model.screen == .overview { DownloadOverview(model: model) }
                    else if model.screen == .updates { UpdateView(settings: model.updateSettings) }
                    else { DownloadView(model: model) }
                    if (model.screen == .downloads || model.screen == .settings), !model.pending.isEmpty {
                        Divider()
                        PendingSubmissionsView(submissions: model.pending, remove: model.removePending)
                    }
                }
                .padding(RelayTheme.pagePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, height in
                    measuredBodyHeight = height
                    reportMeasuredHeight()
                }
            }
            .onChange(of: model.notice) { _, notice in
                if notice != nil { reader.scrollTo("relayNotice", anchor: .top) }
            }
            .onChange(of: model.automaticSubmissionNotice) { _, confirmation in
                if confirmation != nil { reader.scrollTo("submissionConfirmation", anchor: .top) }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 7) {
                Circle().fill(model.configured ? Color.green : Color.secondary).frame(width: 6, height: 6)
                Text(model.configured ? model.serverHost : L("Verbindung einrichten"))
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if !model.pending.isEmpty { Text(L("Wartend: \(model.pending.count)")) }
                else if model.screen != .settings { Text(L("Für deinen Mac")) }
                if model.screen == .settings {
                    Button(L("Speichern")) { model.save() }
                        .relayPrimaryAction()
                        .disabled(model.busy || model.sending)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, RelayTheme.pagePadding).padding(.vertical, 9)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, height in
            measuredFooterHeight = height
            reportMeasuredHeight()
        }
    }

    @ViewBuilder
    private var windowContent: some View {
        if #available(macOS 27.0, *) {
            scrollContent
                .safeAreaBar(edge: .top, spacing: 0) { header }
                .safeAreaBar(edge: .bottom, spacing: 0) { footer }
                .scrollEdgeEffectStyle(.hard, for: [.top, .bottom])
        } else {
            VStack(spacing: 0) {
                header
                scrollContent
                footer
            }
        }
    }

    var body: some View {
        windowContent
        .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 12).stroke(model.appearanceSettings.theme.accent, lineWidth: 3).allowsHitTesting(false) } }
        .onDrop(of: [.fileURL, .url], delegate: RelayImportDropDelegate(
            isTargeted: $dropTargeted, receive: importProviders
        ))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            dropTargeted = false
        }
        .onChange(of: model.screen) { _, _ in dropTargeted = false }
        .fileExporter(
            isPresented: $model.exportPresented,
            item: model.exportFile.map { NZBExportItem(data: $0.data) },
            contentTypes: [NZBExportItem.contentType],
            defaultFilename: model.exportFile.map { $0.title + ".nzb" },
            onCompletion: model.completeExport,
            onCancellation: model.cancelExport
        )
        .confirmationDialog(L("Kategorie auch in SABnzbd löschen?"), isPresented: Binding(
            get: { model.categoryToDelete != nil }, set: { if !$0 { model.categoryToDelete = nil } }
        ), titleVisibility: .visible, presenting: model.categoryToDelete) { name in
            Button(L("In SABnzbd löschen"), role: .destructive) { model.confirmCategoryDeletion(name) }
            Button(L("Abbrechen"), role: .cancel) { model.categoryToDelete = nil }
        } message: { name in
            Text(L("Die Kategorie „\(name)“ wird auch in SABnzbd gelöscht."))
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
    private func importProviders(_ providers: [NSItemProvider]) -> Bool {
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
}

struct SubmissionConfirmationView: View {
    let notice: Notice

    var body: some View {
        Label {
            Text(notice.text)
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .font(.system(size: 13))
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.08), in: RelayControlShape.notice)
        .modifier(RelayControlBorder(shape: RelayControlShape.notice, tint: .green))
    }
}

private struct RelayImportDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let receive: ([NSItemProvider]) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL, .url])
    }

    func dropEntered(info: DropInfo) { isTargeted = validateDrop(info: info) }
    func dropExited(info: DropInfo) { isTargeted = false }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: validateDrop(info: info) ? .copy : .cancel)
    }
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        return receive(info.itemProviders(for: [.fileURL, .url]))
    }
}
