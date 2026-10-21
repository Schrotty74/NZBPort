import SwiftUI
import RelayCore

struct RelayRootView: View {
    @Bindable var model: AppModel
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
                if model.screen == .settings, model.configured {
                    Button { model.screen = .downloads; model.notice = nil } label: {
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
