import SwiftUI
import RelayCore

struct IndexerTestView: View {
    let indexer: IndexerPreferences.Indexer
    let apiKey: String
    let username: String
    let password: String

    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var status = Status.ready
    @State private var task: Task<Void, Never>?

    private enum Status {
        case ready, testing, success, failed(String)
    }

    private var isTesting: Bool {
        if case .testing = status { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("\(indexer.rawValue) testen")).font(.title2.bold())
            Text(L("Der Test sucht beim gewählten Dienst und lädt eine NZB zur Prüfung. Er sendet nichts an SABnzbd."))
                .foregroundStyle(.secondary)
            TextField(L("NZBlnk"), text: $link)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .disabled(isTesting)
                .onChange(of: link) { status = .ready }
            Text(indexer == .easynews
                 ? L("Lass das Feld für die Easynews-Testsuche frei oder setze einen eigenen NZBlnk ein.")
                 : L("Setze einen NZBlnk ein, den dieser Suchdienst finden kann."))
                .font(.caption).foregroundStyle(.secondary)

            switch status {
            case .ready:
                EmptyView()
            case .testing:
                BusyRow(text: L("Suchdienst wird getestet …"))
            case .success:
                Label(L("Test erfolgreich. Die NZB wurde gefunden und geladen."), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange).font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(L("Schließen")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("Suchdienst testen"), action: startTest)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isTesting || (indexer != .easynews && link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding(20)
        .frame(width: 460)
        .onDisappear { task?.cancel() }
    }

    private func startTest() {
        status = .testing
        let input = link
        task = Task {
            do {
                try await IndexerConnectionTest.run(indexer, link: input, apiKey: apiKey,
                                                    username: username, password: password)
                guard !Task.isCancelled else { return }
                status = .success
            } catch {
                guard !Task.isCancelled else { return }
                status = .failed(error.localizedDescription)
            }
        }
    }
}
