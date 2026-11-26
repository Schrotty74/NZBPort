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

- Die Suche läuft nacheinander in der eingestellten Reihenfolge und überspringt deaktivierte Dienste. Standardmäßig sucht NZBPort zuerst bei NZBIndex, NZBKing und BinSearch, dann bei Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder und Videothek. Dienste mit erforderlichem API-Key werden erst verwendet, wenn ihr Key gespeichert ist. Die öffentliche NZBIndex-Suche benötigt keinen separaten API-Key.
- Bei neuen oder geänderten Indexern mit berechtigtem Testzugang eine echte Suche ausführen. Gibt es einen passenden Treffer, auch die NZB-Datei abrufen und prüfen, ohne einen Auftrag an SABnzbd zu senden. Ein Capabilities-Aufruf belegt weder die Suche noch den Abruf. Fehlt der Testzugang oder ein passender Treffer, festhalten, welche Schritte offen sind und welche mit simulierten Antworten geprüft wurden.
- Kategorien von SABnzbd laden. Neue Kategorien nur nach ausdrücklichem Hinzufügen durch den Nutzer in SABnzbd anlegen; vorhandene Kategorien nicht überschreiben. Kategorien nur nach ausdrücklicher Löschaktion mit Bestätigung auch in SABnzbd löschen; die Standardkategorie bleibt geschützt. Ausblenden, Wiederherstellen und Favoriten bleiben lokale Anzeigeentscheidungen.
- Erst nach Kategorieauswahl senden. Wenn der Nutzer „Automatisch erkennen und senden“ aktiviert hat, darf NZBPort eine passend zugeordnete, sichtbare SABnzbd-Kategorie automatisch auswählen. Ohne passende Zuordnung die manuelle Auswahl öffnen. Erfolgreiche Übergabe nur nach SABnzbd-Bestätigung melden.
- Unklare Übertragungsfehler nicht automatisch erneut senden. Duplikatwarnung und manuelle Entscheidung erhalten.
- Nach erfolgreicher Übergabe Fenster schließen oder nächsten Auftrag zeigen; die App bleibt in der Menüleiste.
- Statusabfragen laufen mit zwei Sekunden Wartezeit nach einem Abruf, wenn die Downloadübersicht sichtbar oder Benachrichtigungen eingeschaltet sind. Keine überlappenden Abrufe starten.

## Datenschutz und Portabilität

- Kein Schlüsselbund: SABnzbd-Adresse und API-Key werden nach ausdrücklichem Speichern lokal und unverschlüsselt in App-Einstellungen gehalten. Das ist eine bestätigte Nutzerentscheidung.
- Keine echten API-Keys, privaten Serveradressen, persönlichen NZBlnk-Links, Archivpasswörter oder unbereinigten Screenshots in Quellen, Dokumentation, Logs oder Veröffentlichungen aufnehmen.
- SABnzbd-Key nur an den konfigurierten Server senden, nicht an Suchdienste oder in Browser-URLs.
- Die API-Keys für Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder und Videothek erst beim ausdrücklichen Speichern lokal und unverschlüsselt in den App-Einstellungen ablegen. Nur der jeweilige Anbieter erhält seinen Key für Suche und NZB-Abruf. NZBPort übergibt die geladene NZB-Datei an SABnzbd, da die Downloadadresse den Key enthalten kann.
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
- Sobald die veröffentlichten Downloadpakete samt Prüfsummen auf GitHub geprüft sind, den jeweiligen lokalen Versionsordner unter `Build/Release` in den Papierkorb legen. `Build/NZBPort.app` und die App-Kopie auf MacSoftware unter Download bleiben verfügbar.
- Öffentliche Beschreibung standardmäßig Englisch, zusätzlich Deutsch, gegenseitig verlinkt. Funktionen als Feature-Liste dokumentieren. Gatekeeper-Hinweis erhalten; Ad-hoc-Signierung nicht als Apple-Notarisierung darstellen.
- Nach App-Änderungen die gebaute App auch in die vom Nutzer festgelegte Kopie auf MacSoftware unter Download übernehmen; das bestätigte Ziel steht in PROJECT_CONTEXT.md. Kopie und Signatur prüfen und einen Link zur gebauten App liefern. Selbst geöffnete Apps und Computersteuerung nach Abschluss beenden.
- Nach Änderungen am iPhone-Userscript auf dem Mac die aktuelle Datei als `NZBPort.user.js` neben `NZBPort.app` auf MacSoftware kopieren. Quelle und Kopie byteweise vergleichen.

- Ein Auftrag wie „neue Version erstellen“ oder „neue Testversion erstellen“ umfasst Vorbereitung, erforderliche Prüfungen, bereinigte Dokumentation, Commit, Push, passenden Tag und GitHub-Release mit DMG, ZIP und Prüfsummen. Testversionen als Vorabrelease veröffentlichen. Lokale Dev-Builds bleiben immer lokal. Ein reiner Dev-Build-Auftrag umfasst keinen Commit, Push, Tag oder Release; diese Veröffentlichungskonvention gilt für neue Test- und Finalversionen.

## Changelogs und Release-Notes

- Ausschließlich Englisch verwenden, auch bei nachträglich überarbeiteten älteren Releases.
- Der Changelog von 0.2 dient als verbindliches Muster: konkrete Änderungen unter passenden Abschnitten wie `Added`, `Changed`, gegebenenfalls `Fixed`, anschließend `Requirements and limitations` und `Validation`.
- Nur tatsächlich zutreffende Abschnitte und belegte Änderungen aufnehmen. Prüfergebnisse dem damaligen Release zuordnen; keine späteren Tests rückwirkend behaupten.
- Ältere Changelogs mit derselben Sorgfalt und Struktur pflegen; nicht auf eine allgemeine Kurzbeschreibung reduzieren.
- Den Release-Titel nicht im Beschreibungstext wiederholen. Keine zusätzliche H1-Versionsüberschrift.
