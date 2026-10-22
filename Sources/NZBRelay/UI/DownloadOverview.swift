import SwiftUI
import RelayCore

struct DownloadOverview: View {
    @Bindable var model: AppModel
    var body: some View {
        let monitor = model.monitor
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            HStack {
                Text(L("Downloads")).font(RelayTheme.pageTitleFont)
                Spacer()
                Button { Task { await monitor.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(monitor.refreshing).help(L("Aktualisieren"))
            }
            if !model.configured { Text(L("Bitte zuerst die Verbindung zu SABnzbd einrichten.")) }
            if let error = monitor.error { NoticeView(notice: Notice(error: error)) }
            if let queue = monitor.queue {
                HStack {
                    Label(queue.speed + "B/s", systemImage: "speedometer")
                    Spacer()
                    Label(queue.timeLeft, systemImage: "clock")
                }.font(.system(size: 13)).foregroundStyle(.secondary)
                if !queue.remainingSize.isEmpty {
                    Text(queue.remainingSize).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text(queue.paused ? L("Pausiert") : L("Warteschlange aktiv"))
                    Spacer()
                    Button(queue.paused ? L("Alle fortsetzen") : L("Alle pausieren")) {
                        Task { await monitor.control(queue.paused ? .resume : .pause) }
                    }.disabled(monitor.changing)
                }
                if queue.jobs.isEmpty { Text(L("Keine aktiven Downloads.")).foregroundStyle(.secondary) }
                ForEach(queue.jobs) { job in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(job.title).font(.headline).lineLimit(2)
                        ProgressView(value: job.progress)
                        HStack {
                            Text(localizedJobStatus(job.status)).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            let paused = job.status.lowercased().contains("paused")
                            Button(paused ? L("Fortsetzen") : L("Pausieren")) {
                                Task { await monitor.control(paused ? .resume : .pause, jobID: job.id) }
                            }.controlSize(.small).disabled(monitor.changing)
                        }
                    }.padding(.vertical, 8)
                    Divider()
                }
            } else if monitor.refreshing { BusyRow(text: L("Downloads laden …")) }
            Toggle(L("Abschluss und Fehler melden"), isOn: Binding(
                get: { monitor.notificationsEnabled }, set: { value in Task { await monitor.setNotifications(value) } }
            ))
            Text(L("Statusabfrage alle 2 Sekunden, solange diese Übersicht offen ist oder Benachrichtigungen eingeschaltet sind."))
                .font(.caption).foregroundStyle(.secondary)
            if !monitor.history.isEmpty {
                Divider()
                Text(L("Letzte Aufträge")).font(.headline)
                ForEach(Array(monitor.history.prefix(10))) { job in
                    HStack(alignment: .top) {
                        Image(systemName: job.failed ? "exclamationmark.circle" : (job.status == "Completed" ? "checkmark.circle" : "clock"))
                            .foregroundStyle(job.failed ? Color.orange : (job.status == "Completed" ? Color.green : Color.secondary))
                        VStack(alignment: .leading) {
                            Text(job.title).lineLimit(2)
                            Text(localizedJobStatus(job.status)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

func localizedJobStatus(_ status: String) -> String {
    switch status.lowercased() {
    case "downloading": L("Wird geladen")
    case "queued": L("Wartet")
    case "paused": L("Pausiert")
    case "completed": L("Abgeschlossen")
    case "failed": L("Fehlgeschlagen")
    case "extracting": L("Wird entpackt")
    case "repairing": L("Wird repariert")
    case "verifying", "checking": L("Wird geprüft")
    case "fetching": L("NZB wird geladen")
    default: status
    }
}
