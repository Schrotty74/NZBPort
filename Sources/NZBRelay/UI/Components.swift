import SwiftUI
import RelayCore

struct CategorySendButton: View {
    let name: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: "folder").font(.system(size: 18)).foregroundStyle(RelayTheme.accent)
                Text(name).font(.system(size: 15, weight: .medium)).lineLimit(2)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonBorderShape(.roundedRectangle(radius: RelayTheme.rowRadius))
        .controlSize(.large)
        .accessibilityLabel("An SABnzbd senden: \(name)")
    }
}

struct CategoryPreferenceRow: View {
    let name: String
    let hidden: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hidden ? "eye.slash" : "folder").foregroundStyle(.secondary).frame(width: 20)
            Text(name).lineLimit(2)
            Spacer()
            Button(hidden ? "Wieder einblenden" : "Ausblenden", action: action)
                .font(.system(size: 12)).controlSize(.small)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }
}

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Kategorie suchen", text: $text).textFieldStyle(.plain)
        }
        .padding(10)
        .glassEffect(.regular, in: .capsule)
    }
}

struct BusyRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NoticeView: View {
    let notice: Notice
    var body: some View {
        Label(notice.text, systemImage: notice.isError ? "exclamationmark.circle" : "info.circle")
            .font(.system(size: 13)).textSelection(.enabled)
            .foregroundStyle(notice.isError ? Color.orange : Color.secondary)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background((notice.isError ? Color.orange : Color.secondary).opacity(0.08), in: .rect(cornerRadius: RelayTheme.rowRadius))
    }
}
