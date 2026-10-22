# Projektkontext – NZBPort

Stand: 22. Oktober 2026.

## Projekt und Git-Stand

- Repository: https://github.com/Schrotty74/NZBPort
- Projektpfade beziehen sich auf den Repository-Root; der lokale Ordner trägt historisch den Namen `NZBRelay`.
- Aktueller Branch: `main`. Veröffentlichter App-Quellcommit für 0.2: `74c25ba`; spätere reine Dokumentationscommits ändern die App-Pakete nicht. Weitere Remote-Branches wurden bei dieser Vorbereitung nicht gefunden.
- Veröffentlicht: `v0.2`, Build 4, als GitHub-Vorabrelease mit DMG, ZIP und SHA256SUMS. Ältere Releases: `v0.1.1` und `v0.1.0`.
- App-Stand: Version `0.2`, Build `4`. Quellen, Tests, README und bereinigte Projektdateien sind veröffentlicht. Aktuell ist kein weiterer Release-Auftrag offen.
- Root-`AGENTS.md` verweist auf die vier vollständigen Dateien unter `Documentation/Project/`; alle fünf sind auf GitHub enthalten.

## Produkt

NZBPort öffnet NZBlnk-Links und NZB-Dateien und übergibt sie nach Kategorieauswahl an SABnzbd. Die App bleibt in der Menüleiste; SABnzbd übernimmt den eigentlichen Usenet-Download, Reparatur und Entpacken. Ein eigener NNTP-Downloader ist nicht implementiert und wurde nur als mögliche Erweiterung besprochen.

Die App ist in Swift 6 mit SwiftUI und AppKit geschrieben. Mindestversion ist macOS 26; die vorhandenen Pakete sind für Apple Silicon. Das Projekt verwendet Apple-Systemframeworks und keine externen Swift-Paketabhängigkeiten. Lizenz: GPLv3, siehe `LICENSE`.

## Vorhandene Funktionen

- NZBlnk-Registrierung, Zwischenablage und mehrere wartende Aufträge.
- Eigenständige Link-Auswertung und serielle Suche über NZBIndex, NZBKing und BinSearch. NZBIndex nutzt seine öffentliche API ohne zusätzlichen Such-Key.
- Übernahme von Titel und optionalem Archivpasswort an SABnzbd.
- Kategorien beim Start, beim Öffnen eines Auftrags und manuell laden; Fehler anzeigen. Lokal ausblenden und wiederherstellen.
- Deutsch, Englisch und System-Sprachwahl; Standard, Coffee, Elfenbein und Minze; separate Hell-/Dunkel- und Transparenzeinstellungen.
- Native Liquid-Glass-Bedienelemente und eigenes Icon-Composer-Icon mit Systemdarstellungen.
- Autostart über macOS-Anmeldeobjekte und About-Links zu GitHub und Portfolio.

Zusätzlich im lokalen Stand 0.2:

- NZB-Dateien über Dateiauswahl, Öffnen mit und Drag-and-drop; maximal 16 MiB pro Datei und 64 MiB für gleichzeitig gehaltene Auftragsdaten.
- Priorität oder pausierte Übergabe vor dem Senden wählen.
- Kategorien als Favoriten markieren und deren Reihenfolge ändern.
- Kategorienbereich in den Verbindungseinstellungen auf- und zuklappen; anfangs geöffnet. Der Klappzustand wird nur im Zustand der Ansicht gehalten.
- Gleich große Hauptbuttons für Dateiauswahl und Zwischenablage.
- Downloadübersicht mit Fortschritt, Geschwindigkeit, Restgröße, Restzeit, Verlauf und Pause/Fortsetzen für Auftrag oder Warteschlange.
- Zwei Sekunden Wartezeit zwischen abgeschlossener Statusabfrage und nächstem Abruf, solange Übersicht sichtbar oder Benachrichtigungen aktiv sind. Netzwerklaufzeit kommt hinzu.
- Optionale macOS-Meldungen für abgeschlossene und fehlgeschlagene Aufträge. Standardmäßig aus; macOS-Freigabe erforderlich. Bestehender Verlauf wird beim ersten Abruf nicht pauschal gemeldet, Entpacken gilt noch nicht als Abschluss.
- Duplikatwarnung anhand endpointbezogener Hashes für zehn Minuten im Arbeitsspeicher; keine dauerhafte Speicherung von Titeln oder Passwörtern für diese Prüfung.
- SABnzbd im Browser öffnen, ohne API-Key in der URL.
- Manuelle GitHub-Updateprüfung, optional mit Vorabversionen; kein automatischer Download oder Installer.

## Architektur und wichtige Dateien

| Bereich | Aufgabe |
| --- | --- |
| `Sources/RelayCore` | Parser, Suchanbieter, SABnzbd-Client, NZB-Dateiprüfung, Kategorienmodell und Releaseprüfung |
| `Sources/NZBRelay/AppModel.swift` | Auftragszustand, Konfiguration, Kategorien und Übergabe |
| `Sources/NZBRelay/Main.swift` | App-Lebenszyklus, Fenster und native Menüs |
| `Sources/NZBRelay/System` | Downloadüberwachung, Abschlussverfolgung, Updates und Autostart |
| `Sources/NZBRelay/UI` | Ansichten und Einstellungen |
| `Sources/NZBRelay/Theme` | Darstellung und native Glass-Bedienelemente |
| `Sources/NZBRelay/Localization` | Sprachwahl und Sprachmenü |
| `Sources/RelayCore/Resources` | Deutsche und englische Interface-/Fehlertexte |
| `Resources/NZBPort.icon` | Bearbeitbares App-Icon |
| `Scripts/build.sh` | Release-Build, Ressourcen, Icon-Kompilierung und Ad-hoc-Signierung |
| `Tests` | Swift-Testing-Tests mit synthetischen Daten und Transport-Stubs |

`DownloadMonitor` ruft Warteschlange und Verlauf gemeinsam ab. `CompletionTracker` unterscheidet laufende Nachbearbeitung von terminalen Zuständen. `AppModel` hält aktuelle und wartende Übergaben; ein unklarer Sendefehler führt zu keiner automatischen Wiederholung.

## Einstellungen und Build

Verbindungsdaten liegen nach Speichern unverschlüsselt in lokalen App-Einstellungen; ausdrücklich kein Schlüsselbund. Ausblendungen und Favoriten ändern nicht die SABnzbd-Konfiguration. Der API-Key wird im POST-Inhalt nur an den eingestellten SABnzbd-Endpunkt gesendet.

Öffentliche Bundle-ID: `io.github.Schrotty74.NZBPort`. Der bestehende lokale Entwicklungsbuild nutzt eine historische Kennung zum Erhalt vorhandener Einstellungen. Den vorhandenen App-Build vor einem Neubau auf seine Kennung prüfen; die lokale Kennung nicht in öffentliche Pakete übernehmen. `NZBPORT_BUNDLE_ID` ist der vorhandene Build-Override.

Benötigt werden Xcode mit macOS-26-SDK oder neuer und Icon-Composer-Kompilierung. Der normale Build lautet `zsh Scripts/build.sh`; Ausgabe ist `Build/NZBPort.app`. Interne Produktnamen bleiben `NZBRelay`. Keine neuen Kanalordner oder Branches sind eingerichtet.

## Nachweise und Grenzen

- Vor den letzten kleinen UI-/Intervalländerungen bestanden 45 Core- und 8 App-Tests, zusammen 53. Nachweise liegen lokal unter `Build/Verification/0.1.2/`.
- Nach der Zwei-Sekunden-Änderung und dem klappbaren Kategorienbereich liefen die jeweiligen App-Builds erfolgreich. Sprachdateien wurden für die Intervalländerung syntaktisch geprüft. Kein neuer vollständiger Testlauf für diese kleinen Änderungen.
- Der Nutzer bestätigte den vorherigen Funktionsstand grundsätzlich als funktionierend. Das ist keine gesonderte Bestätigung jedes Benachrichtigungs-, Plattform- oder Fehlerfalls.
- Ein erfolgreicher Build ist kein Nachweis einer UI-Prüfung oder von Tests auf macOS 26 und 27.
- HTML-Suchdienste können ihre Seiten ändern oder Zugriffe sperren. Keine CAPTCHA- oder Zugangssperrenumgehung.
- Englische und deutsche README enthalten die Feature-Liste für 0.2, einschließlich Zwei-Sekunden-Abfrage und Warteschlangensteuerung.

## Änderungsstand 22. Oktober 2026

Statusabfrage von zehn auf zwei Sekunden verkürzt; Hinweise in Deutsch und Englisch angepasst. Kategorienbereich als native DisclosureGroup umgesetzt. Beide App-Builds erfolgreich. Anschließend ausschließlich Projektregeln und Kontextdateien vorbereitet; kein neuer App-Build, Commit oder Upload für diese Dokumentation.

## Lokale Testversion 0.2, Build 4

22. Oktober 2026: Versionsnummer auf Nutzerwunsch auf 0.2 gesetzt. App neu gebaut und ad hoc signiert; DMG mit Applications-Verknüpfung, ZIP, Prüfsummen und englische Versionshinweise unter `Build/Release/0.2/` erstellt. Paketmetadaten, Signatur, private Datenmarker sowie ZIP- und DMG-Integrität geprüft. Frühere bestandene Funktionstests nicht wiederholt; keine neue Bedienungssitzung. Temporäres Paketverzeichnis und die in diesem Auftrag zunächst erzeugten 0.1.2-Pakete entfernt. App-Pakete nicht hochgeladen. Ausschließlich die bestehenden GitHub-Release-Texte für v0.1.0 und v0.1.1 auf ausdrücklichen Auftrag auf Englisch begrenzt; Tags und Assets unverändert.

22. Oktober 2026: Doppelte Produkttitel aus den Beschreibungstexten der GitHub-Releases v0.1.0 und v0.1.1 sowie den lokalen Versionshinweisen 0.2 entfernt. Der jeweilige GitHub-Release-Titel bleibt die einzige Versionsüberschrift. Keine App- oder Paketänderung.

## Veröffentlichungsauftrag für 0.2

22. Oktober 2026: Nutzer stellt klar, dass neue Test- und Finalversionen auch Commit, Upload und GitHub-Release umfassen; lokale Dev-Builds bleiben lokal. Veröffentlichung von 0.2, Build 4, ist ausdrücklich beauftragt. Englische und deutsche Feature-Listen auf 0.2 abgeglichen; englische Release-Notes ohne wiederholten Release-Titel vorbereitet. Der nachfolgende Veröffentlichungsnachtrag dokumentiert das tatsächliche Ergebnis.

## Veröffentlichung 0.2 bestätigt

22. Oktober 2026: https://github.com/Schrotty74/NZBPort/releases/tag/v0.2 als öffentliches Vorabrelease veröffentlicht. App-Quellcommit `74c25ba` auf main; DMG, ZIP und SHA256SUMS vollständig hochgeladen. Die drei GitHub-Asset-Digests stimmen mit den lokalen SHA-256-Werten überein. Der Release-Text ist ausschließlich Englisch und wiederholt den Titel nicht. Keine neue Bedienungssitzung, keine erneuten Funktionstests und keine zusätzlichen App-Kopien zur Prüfung. Lokale Dev-Builds bleiben von der Veröffentlichungskonvention ausgenommen.

22. Oktober 2026: Changelogs v0.1.0 und v0.1.1 auf GitHub in die Struktur der 0.2-Release-Notes überführt: konkrete Funktionen und Änderungen, Voraussetzungen/Einschränkungen sowie damalige Validierung. Ausschließlich Englisch, ohne doppelte Versionsüberschrift. Die Projektregeln schreiben dieses Muster auch für künftige und nachträglich überarbeitete Releases vor.
