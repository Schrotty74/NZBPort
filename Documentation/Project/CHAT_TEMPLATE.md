# Chat-Startvorlage – NZBPort

Ich arbeite an NZBPort: https://github.com/Schrotty74/NZBPort

Verwende den aktuellen Repository-Root; keinen festen lokalen Benutzerpfad voraussetzen. Lies zuerst vollständig die globale `~/.codex/AGENTS.md`, dann die Root-`AGENTS.md` und danach:

1. `Documentation/Project/AGENTS.md`
2. `Documentation/Project/PROJECT_CONTEXT.md`
3. `Documentation/Project/NEXT_STEPS.md`

Prüfe den tatsächlichen Branch und Quellstand. Öffne danach nur die auftragsrelevanten Dateien. Testversion 0.2, Build 4, ist als Vorabrelease v0.2 veröffentlicht; App-Quellcommit `74c25ba` auf `main`. Spätere Dokumentationscommits können darüber liegen. Keine getrennten Dev-/Beta-/Final-Branches voraussetzen und keinen Branch ohne Auftrag wechseln.

NZBPort ist eine native SwiftUI-/AppKit-Menüleisten-App für Apple Silicon ab macOS 26. Sie übergibt NZBlnk-Links und NZB-Dateien an SABnzbd. Die Suchanbieter sind NZBIndex, NZBKing und BinSearch. Kategorien stammen von SABnzbd; Ausblendungen und Favoriten bleiben lokal. Statusabfragen warten zwei Sekunden zwischen Abrufen. Ein vollständiger eigener Usenet-Downloader wurde nur besprochen, nicht beauftragt.

Keinen Schlüsselbund einführen, keine privaten Daten dokumentieren und keine festen lokalen Pfade einbauen. Die bestehende lokale Bundle-ID und damit vorhandene Einstellungen erhalten; öffentliche Pakete verwenden die öffentliche Kennung. Keine vorhandenen Prüfungen oder Bedienungsbestätigungen als neue Tests ausgeben.

Prüfungen bündeln und nur bei konkretem Anlass wiederholen. Nach Builds die vier Projektdateien prüfen und relevante Änderungen nachführen. Keine zusätzlichen Prüf-Apps oder Projektkopien ohne ausdrücklichen Auftrag.

Ohne ausdrücklichen Auftrag keine Commits, Pushes, Tags oder Releases. Neue Test- und Finalversion erstellen umfasst auch die Veröffentlichung; lokale Dev-Builds bleiben lokal. Nach App-Änderungen den Link zur gebauten App liefern. Selbst geöffnete Apps und Computersteuerung nach Abschluss beenden.

Aktueller Auftrag:

<Aktueller Auftrag>
