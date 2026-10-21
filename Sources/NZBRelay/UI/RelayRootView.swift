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
                    .foregroundStyle(RelayTheme.accent)
                    .accessibilityHidden(true)
                Text("NZBPort").font(RelayTheme.brandFont)
                Spacer()
                if model.screen == .settings, model.configured {
                    Button { model.screen = .downloads; model.notice = nil } label: {
                        Label("Zurück", systemImage: "arrow.left")
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
                Text(model.configured ? model.serverHost : "Verbindung einrichten")
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if !model.pending.isEmpty { Text("\(model.pending.count) weitere Links") }
                else { Text("Für deinen Mac") }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, RelayTheme.pagePadding).padding(.vertical, 9)
        }
        .frame(minWidth: RelayTheme.minimumWindowSize.width,
               minHeight: RelayTheme.minimumWindowSize.height - 28)
        .background { RelayBackground(style: model.appearanceSettings.background) }
        .preferredColorScheme(model.appearanceSettings.mode.colorScheme)
        .relayGlassControls()
    }
}
