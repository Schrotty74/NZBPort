# Chat-Startvorlage – NZBPort

Ich arbeite an NZBPort: https://github.com/Schrotty74/NZBPort

Verwende den aktuellen Repository-Root; keinen festen lokalen Benutzerpfad voraussetzen. Lies zuerst vollständig die globale `~/.codex/AGENTS.md`, dann die Root-`AGENTS.md` und danach:

1. `Documentation/Project/AGENTS.md`
2. `Documentation/Project/PROJECT_CONTEXT.md`
3. `Documentation/Project/NEXT_STEPS.md`

Prüfe den tatsächlichen Branch und Quellstand. Öffne danach nur die auftragsrelevanten Dateien. Testversion 0.2.6, Build 10, ergänzt Videothek und die Korrekturen für DrunkenSlug und NZBFinder. Das aktuelle iOS-Userscript liegt unter Userscripts/NZBPort.user.js vor. Die Planung für den eigenen Downloader mit Handy-Weboberfläche steht in NEXT_STEPS.md. Keine getrennten Dev-/Beta-/Final-Branches voraussetzen und keinen Branch ohne Auftrag wechseln.

NZBPort ist eine native SwiftUI-/AppKit-Menüleisten-App für Apple Silicon ab macOS 26. Sie übergibt NZBlnk-Links und NZB-Dateien an SABnzbd. Nach NZBIndex, NZBKing und BinSearch folgen Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder und Videothek, wenn ihre jeweiligen API-Keys eingerichtet sind. Kategorien haben einen eigenen Bereich; neue Kategorien lassen sich dort ausdrücklich in SABnzbd anlegen und vorhandene nach Bestätigung löschen. Die Standardkategorie ist geschützt. Ausblendungen und Favoriten bleiben lokal. Zwischen Statusabfragen liegen zwei Sekunden Wartezeit.

Keinen Schlüsselbund einführen, keine privaten Daten dokumentieren und keine festen lokalen Pfade einbauen. Die bestehende lokale Bundle-ID und damit vorhandene Einstellungen erhalten; öffentliche Pakete verwenden die öffentliche Kennung. Keine vorhandenen Prüfungen oder Bedienungsbestätigungen als neue Tests ausgeben.

Prüfungen bündeln und nur bei konkretem Anlass wiederholen. Nach Builds die vier Projektdateien prüfen und relevante Änderungen nachführen. Keine zusätzlichen Prüf-Apps oder Projektkopien ohne ausdrücklichen Auftrag.

Ohne ausdrücklichen Auftrag keine Commits, Pushes, Tags oder Releases. Neue Test- und Finalversion erstellen umfasst auch die Veröffentlichung; lokale Dev-Builds bleiben lokal. Nach App-Änderungen den Link zur gebauten App liefern. Selbst geöffnete Apps und Computersteuerung nach Abschluss beenden.

Lokal ergänzte macOS-27-Oberfläche: eigener Glasstil für Zahnrad und die Aktualisieren-Buttons neben „Kategorie wählen“ sowie auf „Deine Kategorien“, Favoriten per Drag-and-drop, Berücksichtigung von „Ränder anzeigen“ und konzentrische Hinweiskarten. Unter macOS 26 bleiben die bisherigen Bedienelemente. 125 Tests und lokaler Build bestanden; Die korrigierte Favoriten-Ziehgeste und der Refresh-Button auf „Deine Kategorien“ wurden anschließend mit Nutzerzustimmung tatsächlich bedient; Details und Grenzen in PROJECT_CONTEXT.md. Details in PROJECT_CONTEXT.md.

Videothek hat die festen Präfixe für die Mac-App und das iOS-Skript freigegeben. Die Kennungen stehen in NewznabClient.userAgent und in Userscripts/NZBPort.user.js. Keine Keys dokumentieren.

Aktueller Auftrag:

<Aktueller Auftrag>
