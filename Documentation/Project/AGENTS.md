# Projektregeln für NZBPort

## Dokumentation

- Diese Regeln gelten für das gesamte Repository.
- Dauerhafte Regeln stehen hier, der belegte Projektstand in `PROJECT_CONTEXT.md`, offene Arbeit in `NEXT_STEPS.md` und der Chat-Einstieg in `CHAT_TEMPLATE.md`.
- Nach jedem Build alle vier Dateien prüfen und relevante Änderungen sowie tatsächliche Prüfergebnisse nachführen. Unveränderte Dokumente nicht künstlich umschreiben.
- Keine Funktionen, Testergebnisse oder Veröffentlichungen erfinden. Quellprüfung, Build, automatisierte Tests und bestätigte Bedienung unterscheiden.
- Die globalen Agentenregeln bleiben außerhalb des Repositorys; sie werden hier nicht kopiert.

## Produkt und Architektur

- NZBPort ist eine native macOS-Menüleisten-App für NZBlnk-Links und NZB-Dateien mit SABnzbd-Anbindung.
- Apple Silicon und macOS 26 als Mindestversion erhalten. Neue APIs auf Verfügbarkeit prüfen; Unterstützung neuerer macOS-Versionen nicht ohne Prüfung als getestet darstellen.
- SwiftUI und AppKit verwenden. Oberfläche, Themes, Lokalisierung, Suchdienste und SABnzbd-Kommunikation modular halten.
- Native Liquid-Glass-Bedienelemente, Systemdarstellung und manuelle Hell-/Dunkelwahl erhalten. Die Titelleiste darf nicht wieder unbeabsichtigt transparent werden.
- App-Code ist eine eigenständige Swift-Implementierung. Keine fremden Userscripts einbetten oder ausführen. Apple-Systemframeworks werden verwendet; externe Paketabhängigkeiten bestehen derzeit nicht.
- Ein vollständiger eigener Usenet-Downloader wurde nur besprochen und ist nicht beauftragt.

## Links, Kategorien und Downloads

- NZBlnk-Suche: NZBIndex, danach NZBKing und BinSearch. Die öffentliche NZBIndex-Suche benötigt keinen separaten API-Key.
- Kategorien von SABnzbd laden. Ausblenden, Wiederherstellen und Favoriten bleiben lokale Anzeigeentscheidungen; keine Kategorien in SABnzbd anlegen oder löschen.
- Erst nach Kategorieauswahl senden. Erfolgreiche Übergabe nur nach SABnzbd-Bestätigung melden.
- Unklare Übertragungsfehler nicht automatisch erneut senden. Duplikatwarnung und manuelle Entscheidung erhalten.
- Nach erfolgreicher Übergabe Fenster schließen oder nächsten Auftrag zeigen; die App bleibt in der Menüleiste.
- Statusabfragen laufen mit zwei Sekunden Wartezeit nach einem Abruf, wenn die Downloadübersicht sichtbar oder Benachrichtigungen eingeschaltet sind. Keine überlappenden Abrufe starten.

## Datenschutz und Portabilität

- Kein Schlüsselbund: SABnzbd-Adresse und API-Key werden nach ausdrücklichem Speichern lokal und unverschlüsselt in App-Einstellungen gehalten. Das ist eine bestätigte Nutzerentscheidung.
- Keine echten API-Keys, privaten Serveradressen, persönlichen NZBlnk-Links, Archivpasswörter oder unbereinigten Screenshots in Quellen, Dokumentation, Logs oder Veröffentlichungen aufnehmen.
- SABnzbd-Key nur an den konfigurierten Server senden, nicht an Suchdienste oder in Browser-URLs.
- Keine festen lokalen Benutzer-, Installations- oder Datenträgerpfade einbauen. Ressourcen relativ zum Bundle und Projektdateien relativ zum Repository laden.
- Die bestehende lokale Bundle-ID nicht unbemerkt durch die öffentliche Kennung ersetzen: Einstellungen sind daran gebunden. Keine privaten Kennungen in öffentliche Pakete übernehmen.

## Build und Veröffentlichung

- `Package.swift`, `Scripts/build.sh` und `Resources/Info.plist` sind die vorhandenen Build-Grundlagen. Interne Targets heißen weiterhin `NZBRelay` und `RelayCore`.
- `swift test` führt automatisierte Tests aus; `zsh Scripts/build.sh` erstellt `Build/NZBPort.app`. Der Build signiert ad hoc und veröffentlicht nichts.
- Keine Zertifikate, Teams, Accounts oder Abhängigkeiten eigenmächtig installieren oder ändern.
- Ohne ausdrücklichen Auftrag keine Commits, Pushes, Tags, Releases, Branchwechsel oder Zusammenführungen. Ein lokaler Build ist keine Upload-Freigabe.
- Veröffentlichungsziel: https://github.com/Schrotty74/NZBPort . Derzeit besteht nur `main`; keine Dev-/Beta-/Final-Branchstruktur anderer Apps übernehmen.
- Bei beauftragter Veröffentlichung bereinigte Quellen, baurelevante Ressourcen, Tests und öffentliche Dokumentation gezielt auswählen. Private `Documentation`-Inhalte werden durch die vier erlaubten Projektdateien nicht freigegeben.
- Beauftragte Downloadpakete als DMG mit Applications-Verknüpfung sowie ZIP bereitstellen; Signatur, Paketinhalt und Prüfsummen prüfen. Keine lokalen Einstellungen verpacken.
- Öffentliche Beschreibung standardmäßig Englisch, zusätzlich Deutsch, gegenseitig verlinkt. Funktionen als Feature-Liste dokumentieren. Gatekeeper-Hinweis erhalten; Ad-hoc-Signierung nicht als Apple-Notarisierung darstellen.
- Nach App-Änderungen einen Link zur gebauten App liefern. Selbst geöffnete Apps und Computersteuerung nach Abschluss beenden.

- Changelog und GitHub-Release-Notes ausschließlich auf Englisch verfassen; die allgemeine README und App-Oberfläche bleiben zweisprachig.

- GitHub-Release-Titel nicht als Überschrift im Beschreibungstext wiederholen. Release-Notes beginnen direkt mit Inhalt oder Unterabschnitten.

- Ein Auftrag wie „neue Version erstellen“ oder „neue Testversion erstellen“ umfasst Vorbereitung, erforderliche Prüfungen, bereinigte Dokumentation, Commit, Push, passenden Tag und GitHub-Release mit DMG, ZIP und Prüfsummen. Testversionen als Vorabrelease veröffentlichen. Lokale Dev-Builds bleiben immer lokal. Ein reiner Dev-Build-Auftrag umfasst keinen Commit, Push, Tag oder Release; diese Veröffentlichungskonvention gilt für neue Test- und Finalversionen.

## Changelogs und Release-Notes

- Ausschließlich Englisch verwenden, auch bei nachträglich überarbeiteten älteren Releases.
- Der Changelog von 0.2 dient als verbindliches Muster: konkrete Änderungen unter passenden Abschnitten wie `Added`, `Changed`, gegebenenfalls `Fixed`, anschließend `Requirements and limitations` und `Validation`.
- Nur tatsächlich zutreffende Abschnitte und belegte Änderungen aufnehmen. Prüfergebnisse dem damaligen Release zuordnen; keine späteren Tests rückwirkend behaupten.
- Ältere Changelogs mit derselben Sorgfalt und Struktur pflegen; nicht auf eine allgemeine Kurzbeschreibung reduzieren.
- Den Release-Titel nicht im Beschreibungstext wiederholen. Keine zusätzliche H1-Versionsüberschrift.
