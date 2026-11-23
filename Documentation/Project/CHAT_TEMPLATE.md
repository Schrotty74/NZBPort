# Chat-Startvorlage – NZBPort

Ich arbeite an NZBPort: https://github.com/Schrotty74/NZBPort

Verwende den aktuellen Repository-Root; keinen festen lokalen Benutzerpfad voraussetzen. Lies zuerst vollständig die globale `~/.codex/AGENTS.md`, dann die Root-`AGENTS.md` und danach:

1. `Documentation/Project/AGENTS.md`
2. `Documentation/Project/PROJECT_CONTEXT.md`
3. `Documentation/Project/NEXT_STEPS.md`

Prüfe den tatsächlichen Branch und Quellstand. Öffne danach nur die auftragsrelevanten Dateien. Release-Stand 0.2.5, Build 9, enthält Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug und NZBFinder sowie NZB-Speicherung, eigene Kategorienverwaltung und korrigierte Fensterhöhen. Das separate iOS-Userscript v2.3.6 bietet ebenfalls NZB-Speicherung und enthält kein NZBGet mehr. Die Planung für den eigenen Downloader mit Handy-Weboberfläche steht in NEXT_STEPS.md. Keine getrennten Dev-/Beta-/Final-Branches voraussetzen und keinen Branch ohne Auftrag wechseln.

NZBPort ist eine native SwiftUI-/AppKit-Menüleisten-App für Apple Silicon ab macOS 26. Sie übergibt NZBlnk-Links und NZB-Dateien an SABnzbd. Nach NZBIndex, NZBKing und BinSearch folgen Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug und NZBFinder, wenn ihre jeweiligen API-Keys eingerichtet sind. Kategorien haben einen eigenen Bereich; neue Kategorien lassen sich dort ausdrücklich in SABnzbd anlegen und vorhandene nach Bestätigung löschen. Die Standardkategorie ist geschützt. Ausblendungen und Favoriten bleiben lokal. Zwischen Statusabfragen liegen zwei Sekunden Wartezeit.

Keinen Schlüsselbund einführen, keine privaten Daten dokumentieren und keine festen lokalen Pfade einbauen. Die bestehende lokale Bundle-ID und damit vorhandene Einstellungen erhalten; öffentliche Pakete verwenden die öffentliche Kennung. Keine vorhandenen Prüfungen oder Bedienungsbestätigungen als neue Tests ausgeben.

Prüfungen bündeln und nur bei konkretem Anlass wiederholen. Nach Builds die vier Projektdateien prüfen und relevante Änderungen nachführen. Keine zusätzlichen Prüf-Apps oder Projektkopien ohne ausdrücklichen Auftrag.

Ohne ausdrücklichen Auftrag keine Commits, Pushes, Tags oder Releases. Neue Test- und Finalversion erstellen umfasst auch die Veröffentlichung; lokale Dev-Builds bleiben lokal. Nach App-Änderungen den Link zur gebauten App liefern. Selbst geöffnete Apps und Computersteuerung nach Abschluss beenden.

Aktueller Auftrag:

<Aktueller Auftrag>
