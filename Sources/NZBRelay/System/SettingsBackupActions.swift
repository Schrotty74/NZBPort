import AppKit
import RelayCore
import UniformTypeIdentifiers

extension AppModel {
    func exportSettings() {
        guard canManageSettings else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "NZBPort-Einstellungen.json"
        panel.message = L("Die Sicherung enthält alle NZBPort-Einstellungen und deine Zugangsdaten im Klartext.")
        panel.begin { [weak self] result in
            guard result == .OK, let self, let url = panel.url else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try self.settingsBackup().encoded().write(to: url, options: .atomic)
                self.notice = Notice(text: "Einstellungen exportiert.", isError: false)
            } catch { self.notice = Notice(error: error) }
        }
    }

    func importSettings() {
        guard canManageSettings else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] result in
            guard result == .OK, let self, let url = panel.url else { return }
            do {
                let backup = try SettingsBackup.read(from: url)
                let server = try backup.connection.validatedServer()
                let alert = NSAlert()
                alert.messageText = L("Einstellungen importieren?")
                alert.informativeText = L("Die Sicherung ersetzt Verbindungen, Zugangsdaten, Kategorien, Erkennungsregeln und die weiteren NZBPort-Einstellungen.")
                if let endpoint = server?.endpoint {
                    alert.informativeText += "\n\n" + L("SABnzbd-Adresse: \(endpoint.absoluteString)")
                }
                if backup.categories.recognition.automaticallySends {
                    alert.informativeText += "\n\n" + L("Diese Sicherung aktiviert „Automatisch erkennen und senden“.")
                }
                if let folder = backup.watchedDownloadFolder {
                    alert.informativeText += "\n\n" + L("Überwachter Downloadordner: \(folder)")
                }
                alert.addButton(withTitle: L("Importieren"))
                alert.addButton(withTitle: L("Abbrechen"))
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                self.restoreSettings(backup, success: "Einstellungen importiert.")
            } catch { self.notice = Notice(error: error) }
        }
    }

    func resetSettings() {
        guard canManageSettings else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("Einstellungen zurücksetzen?")
        alert.informativeText = L("NZBPort setzt seine Einstellungen auf Standard und entfernt die gespeicherten Verbindungen und Zugangsdaten. Aufträge in SABnzbd bleiben erhalten.")
        let reset = alert.addButton(withTitle: L("Zurücksetzen"))
        reset.hasDestructiveAction = true
        reset.keyEquivalent = ""
        alert.addButton(withTitle: L("Abbrechen")).keyEquivalent = "\r"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        restoreSettings(.standard, success: "Einstellungen auf Standard zurückgesetzt.")
    }

    private func restoreSettings(_ backup: SettingsBackup, success: String.LocalizationValue) {
        Task {
            do {
                let followUp = try await applySettingsBackup(backup)
                let message = ([L(success)] + followUp).joined(separator: " ")
                notice = Notice(text: "\(message)", isError: false)
            } catch { notice = Notice(error: error) }
        }
    }
}
