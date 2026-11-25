# Projektkontext – NZBPort

Stand: 24. November 2026.

## Projekt und Git-Stand

- Repository: https://github.com/Schrotty74/NZBPort
- Projektpfade beziehen sich auf den Repository-Root; der lokale Ordner trägt historisch den Namen `NZBRelay`.
- Entwicklungsbranch: `main`. Der App-Quellcommit für 0.2 war `74c25ba`; danach folgten Dokumentationscommits.
- Vorheriger Release-Stand: Testversion 0.2.5, Build 9, mit NinjaCentral, DrunkenSlug und NZBFinder, NZB-Speicherung, eigenem Kategorienbereich sowie überarbeiteten Verbindungsansichten und Fensterhöhen. GitHub-Tag: `v0.2.5`.
- Testversion 0.2.4, Build 8, ergänzte Treasure Maps und NewzBay. In 0.2.3, Build 7, kam das Warten auf SABnzbd beim Anmeldestart hinzu.
- Root-`AGENTS.md` verweist auf die vier vollständigen Dateien unter `Documentation/Project/`; alle fünf sind auf GitHub enthalten.

## Produkt

NZBPort öffnet NZBlnk-Links und NZB-Dateien und übergibt sie nach Kategorieauswahl an SABnzbd. Die App bleibt in der Menüleiste; SABnzbd übernimmt den eigentlichen Usenet-Download, Reparatur und Entpacken. Ein eigener NNTP-Downloader ist nicht implementiert und wurde nur als mögliche Erweiterung besprochen.

Die App ist in Swift 6 mit SwiftUI und AppKit geschrieben. Mindestversion ist macOS 26; die vorhandenen Pakete sind für Apple Silicon. Das Projekt verwendet Apple-Systemframeworks und keine externen Swift-Paketabhängigkeiten. Lizenz: GPLv3, siehe `LICENSE`.

## Vorhandene Funktionen

- NZBlnk-Registrierung, Zwischenablage und mehrere wartende Aufträge.
- Eigenständige Link-Auswertung und serielle Suche über NZBIndex, NZBKing und BinSearch. NZBIndex nutzt seine öffentliche API ohne zusätzlichen Such-Key.
- Seit 0.2.4 kann NZBPort nach den öffentlichen Suchdiensten bei Treasure Maps und danach bei NewzBay nach dem Releasetitel suchen. Beide Anbieter haben ein eigenes optionales API-Key-Feld. NZBPort übernimmt einen eindeutigen Treffer mit passendem Titel.
- Übernahme von Titel und optionalem Archivpasswort an SABnzbd.
- Kategorien beim Start, beim Öffnen eines Auftrags und manuell laden; Fehler anzeigen. Lokal ausblenden und wiederherstellen.
- Deutsch, Englisch und System-Sprachwahl; Standard, Coffee, Elfenbein und Minze; separate Hell-/Dunkel- und Transparenzeinstellungen.
- Native Liquid-Glass-Bedienelemente und eigenes Icon-Composer-Icon mit Systemdarstellungen.
- Autostart über macOS-Anmeldeobjekte und About-Links zu GitHub und Portfolio.

Zusätzlich in der veröffentlichten Testversion 0.2:

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

22. Oktober 2026: Changelogs v0.1.0 und v0.1.1 auf GitHub nach dem Muster von 0.2 überarbeitet und geprüft.

## Stand für die Chat-Fortsetzung

22. Oktober 2026: Repository vor dieser Vorbereitung sauber, main und origin/main auf `0f92fcb`. Die doppelten Changelog-Regeln sind im veröffentlichten Dokumentationsstand entfernt; der verbindliche Abschnitt steht einmal in `Documentation/Project/AGENTS.md`. Für die Chat-Vorbereitung nur `PROJECT_CONTEXT.md` und `CHAT_TEMPLATE.md` lokal aktualisiert. Kein Build, Testlauf, Commit, Push oder Release ausgeführt. Offene Bedienungsbestätigungen stehen unverändert in `NEXT_STEPS.md`.

## Lokale Autostart-Korrektur

29. Oktober 2026: `Main.swift` erkennt den Start als macOS-Anmeldeobjekt anhand des Apple Events (`kAEOpenApplication` mit `keyAEPropData` gleich `keyAELaunchedAsLogInItem`). Bei diesem Start wird das Hauptfenster nicht geöffnet; die App bleibt in der Menüleiste. Manuelles Öffnen sowie NZB-Dateien und NZBlnk-Links öffnen weiterhin das Fenster.

Lokaler Dev-Build erfolgreich, vorhandene lokale Bundle-ID erhalten. Ad-hoc-Signatur und Info.plist im Build geprüft. Version 0.2 und Build 4 unverändert. Keine automatisierten Tests und kein echter Anmeldestart durchgeführt; die Bedienungsbestätigung steht noch aus. Keine Veröffentlichung.

## Testversion 0.2.1, Build 5

3. November 2026: Die Autostart-Korrektur für das Vorabrelease gebaut. Die automatisierten Tests bestanden. Ein echter Anmeldestart wurde nicht geprüft. Die Pakete verwenden die öffentliche Bundle-ID.

## Änderungen in Testversion 0.2.2, Build 6

14. November 2026: Die Startgröße des Hauptfensters beträgt jetzt 500 × 660 Punkte. Passt das Fenster nicht in den sichtbaren Bildschirmbereich, begrenzt die App die Höhe. Der Inhalt bleibt scrollbar. Der lokale Dev-Build und seine Signaturprüfung waren erfolgreich. Die neue Fenstergröße wurde noch nicht in der App geprüft.

Die automatische Höhenanpassung gilt für alle Ansichten im Hauptfenster, auch für die Verbindungseinstellungen mit aufgeklappten Kategorien. Passt der Inhalt nicht ins Fenster, wächst es bis zum sichtbaren Bildschirmrand. Wer die Größe von Hand ändert, behält sie bis zum nächsten Öffnen. Der lokale Build und die Signaturprüfung waren erfolgreich. Die Darstellung in den Verbindungseinstellungen wurde noch nicht in der laufenden App geprüft.

Beim Start und beim Aktivieren liest NZBPort die macOS-Zuordnung für NZBlnk-Links. Ist dieser Build als Standard-App eingetragen, zeigt der Button „Als Link-App eingerichtet“. Der lokale Build und die Signaturprüfung waren erfolgreich. Die macOS-Abfrage bestätigte die Zuordnung zum lokalen Build; der Nutzer bestätigte anschließend die Anzeige nach dem Neustart.

Die Downloadübersicht zeigt unter dem Status jedes Auftrags in der SABnzbd-Warteschlange auch dessen Kategorie. Für die Anzeige werden die vorhandenen Warteschlangendaten verwendet. Die deutschen und englischen Sprachdateien, der lokale Build und seine Signatur wurden geprüft. Die Anzeige mit einem laufenden Download wurde noch nicht geprüft.

NZBPort listet wartende NZBlnk-Links und NZB-Dateien in der Übergabeansicht und in den Verbindungseinstellungen. Einzelne Einträge lassen sich vor der Übergabe entfernen. Der aktuelle Auftrag bleibt dabei erhalten. Die Sprachdateien, der lokale Build und die Signatur wurden geprüft. Die Liste wurde noch nicht in der laufenden App getestet.

Oben im Menüleistensymbol zeigt NZBPort die Zahl der Aufträge in der SABnzbd-Warteschlange und, wenn verfügbar, die Geschwindigkeit. Das Menü zeigt auch an, wenn die Warteschlange leer oder pausiert ist, die Verbindung noch nicht eingerichtet ist oder der Statusabruf fehlschlägt. Beim Öffnen aktualisiert der vorhandene Downloadmonitor die Anzeige, sofern noch kein Abruf läuft. Sprachdateien, lokaler Build und Signatur wurden geprüft. Die Anzeige im geöffneten Menü wurde noch nicht in der laufenden App geprüft.

Für 0.2.2 bestanden alle 53 automatisierten Tests. Die App im DMG wurde auf ihre Signatur geprüft. DMG, ZIP und SHA-256-Prüfsummen wurden vor dem Upload geprüft. Die neuen Ansichten wurden im Release-Build nicht praktisch getestet.

## Testversion 0.2.3, Build 7: Kategorien beim Anmeldestart

Beim macOS-Anmeldestart bleibt NZBPort in der Menüleiste. Ist SABnzbd vorübergehend nicht erreichbar, wiederholt NZBPort den Kategorienabruf im Hintergrund bis zu dreimal. Bei Erfolg zeigt die App keine Warnung. Nach dem letzten erfolglosen Versuch oder bei einem Fehler wie einer abgelehnten Anmeldung zeigt sie die Meldung weiterhin an. Der manuelle App-Start und die Downloadübergabe sind unverändert. Die automatisierten Tests, der lokale Build und die Signaturprüfung waren erfolgreich. Der Nutzer bestätigte am 16. November 2026, dass beim morgendlichen Anmeldestart keine Kategorienwarnung erschien.

Die Planung für einen eigenen Downloader steht in NEXT_STEPS.md: Downloads ausschließlich auf dem Mac, Bedienung am Handy über eine Weboberfläche im Heimnetz. Kein separater NAS-/Serverdienst. Die Umsetzung ist nicht beauftragt. Die Rust-Glasprobe wurde auf Nutzerauftrag vollständig entfernt.

18. November 2026: Version 0.2.3, Build 7, für das GitHub-Vorabrelease vorbereitet. Core- und App-Tests bestanden, einschließlich Wiederherstellung nach vorübergehenden Startfehlern und Meldung dauerhafter Fehler. Öffentliche Bundle-ID, Apple-Silicon-Architektur, Ad-hoc-Signatur, DMG mit Applications-Verknüpfung, ZIP und SHA-256-Prüfsummen geprüft. README und Detailseiten in beiden Sprachen sowie Chatvorlage und nächste Schritte nachgeführt.

## Lokale Treasure-Maps-Suche

21. November 2026: Das optionale API-Key-Feld steht in den Verbindungseinstellungen. Beim Speichern wird der Key lokal und unverschlüsselt abgelegt. Die App verwendet für Treasure Maps den Releasetitel aus dem NZBlnk und prüft den Titel des Treffers. Da die Downloadadresse den Key enthalten kann, lädt NZBPort die NZB-Datei selbst und übergibt sie mit der gewählten Kategorie und dem optionalen Archivpasswort an SABnzbd.

Alle 63 automatisierten Tests bestanden. Lokaler Build und Signaturprüfung waren erfolgreich. Der Nutzer bestätigte danach, dass er alle drei zunächst fehlenden Releases mit der integrierten Treasure-Maps-Suche gefunden hat.

## Lokale NewzBay-Suche

21. November 2026: NewzBay ist mit eigenem API-Key als Ausweichsuche nach Treasure Maps eingerichtet. Beide Anbieter nutzen denselben Newznab-Client. NZBPort lädt die Datei bei NewzBay anhand der Treffer-ID und übergibt sie ohne die NewzBay-Downloadadresse an SABnzbd.

Die öffentliche NewzBay-API bestätigte die Titelsuche. Die zwei angemeldeten Suchanfragen für die gemeldete Folge lieferten HTTP 429 mit dem Hinweis auf das Anfragelimit. Es gab keine Trefferliste. Alle 67 automatisierten Tests bestanden. Der lokale Build und seine Signatur wurden geprüft. Die Darstellung im laufenden Build und die erste erfolgreiche Übergabe eines NewzBay-Treffers stehen noch aus.

## Testversion 0.2.4, Build 8

21. November 2026: Treasure Maps und NewzBay in das GitHub-Vorabrelease aufgenommen. Für 0.2.4 bestanden alle 67 automatisierten Tests. Geprüft wurden außerdem die öffentliche Bundle-ID, Apple-Silicon-Architektur, Ad-hoc-Signatur, die App in DMG und ZIP, der Applications-Link und die SHA-256-Prüfsummen. Die App wurde für diese Prüfung nicht gestartet.

## Lokale NinjaCentral-Suche

22. November 2026: NinjaCentral folgt nach Treasure Maps und NewzBay als weiterer optionaler Suchdienst. In den Verbindungseinstellungen gibt es dafür ein eigenes API-Key-Feld. Der Key wird erst beim Speichern lokal und unverschlüsselt abgelegt. Die App übernimmt nur einen eindeutigen Treffer mit passendem Releasetitel, lädt die NZB-Datei selbst und übergibt deren Inhalt an SABnzbd. Für den NZB-Abruf sind HTTPS-Weiterleitungen innerhalb von ninjacentral.co.za erlaubt; die bisherigen Weiterleitungsregeln der anderen Anbieter bleiben erhalten.

Das separate iOS-Userscript wurde auf v2.3.2 erweitert. Es enthält denselben zusätzlichen Suchdienst und ein eigenes optionales Key-Feld. Die Kopien im bestehenden iCloud-Userscripts-Ordner und unter Downloads sind identisch. Das Script wird weiterhin nicht in die Mac-App eingebettet. Bei NinjaCentral prüft es die gemeldete endgültige Antwortadresse; die tatsächliche Weiterleitung führt Userscripts aus.

Der direkte NinjaCentral-Test lieferte einen passenden Suchtreffer und eine gültige NZB-Datei. Es wurde kein Download an SABnzbd gesendet. Alle 71 automatisierten Swift-Tests bestanden, darunter Tests für Treffer-ID, Dateiabruf, Weiterleitungsregeln und gespeicherte Einstellungen. Der lokale App-Build und die Signaturprüfung waren erfolgreich; die bestehende lokale Bundle-ID blieb erhalten. Sprachdateien, Script-Syntax und simulierte Script-Anfragen wurden geprüft. Die Bedienung der ergänzten Mac-Oberfläche und des Scripts auf dem iPhone wurde noch nicht geprüft. Keine Veröffentlichung.

## iOS-Userscript v2.3.4

22. November 2026: Der wirkungslose Schalter für Erfolgs-Benachrichtigungen wurde entfernt. Auf weiteren Nutzerauftrag wurde NZBGet vollständig entfernt. Neben den SABnzbd-Kategorien steht jetzt „NZB-Datei speichern“. Die Option bleibt auch ohne SABnzbd-Konfiguration, bei fehlgeschlagenem Kategorienabruf und nach einem Sendefehler verfügbar. Die vorhandene Ausgabe „Download“ speichert direkt; die direkte SABnzbd-Ausgabe berücksichtigt wieder die eingestellte Standardkategorie.

Beim Speichern werden HTTP-Fehler und ungültige NZB-Antworten abgewiesen. Ein vorhandenes Archivpasswort bleibt in der bisherigen Dateinamenskonvention erhalten. Alte Einstellungen werden auf unterstützte Felder begrenzt; entfernte Ausgabearten wechseln zum SABnzbd-Menü. Die Kopien im iCloud-Userscripts-Ordner und unter Downloads sind identisch. Syntaxprüfung und simulierte Prüfungen für Einstellungen, öffentliche und API-Suchdienste, Dateispeicherung, fehlende SABnzbd-Verbindung sowie erfolgreiche und fehlgeschlagene Übergaben bestanden. Der Nutzer bestätigte anschließend, dass das Speichern der NZB-Datei auf seinem iPhone funktioniert. Die Mac-App wurde für diese Script-Änderungen nicht geändert oder neu gebaut.

## Lokales Speichern von NZB-Dateien in der Mac-App

22. November 2026: „NZB-Datei speichern …“ steht in der Auftragsansicht und bei einem wartenden Auftrag in den Verbindungseinstellungen. Für NZBlnk-Links nutzt die App dieselben Suchdienste und gespeicherten API-Keys wie beim Senden. Sie lädt und prüft die NZB-Datei, bevor der native macOS-Speicherdialog erscheint. Das Speichern benötigt keine SABnzbd-Verbindung und sendet keinen Auftrag. Importierte NZB-Dateien können ebenfalls gespeichert werden. Der aktuelle Auftrag bleibt nach Speichern, Abbrechen und Fehlern erhalten.

Ein im Link enthaltenes Archivpasswort wird unverändert als NZB-Passwortmetadatum übernommen; der Dateiname enthält den bereinigten Releasetitel. Die ursprünglichen Dateidaten werden vor der Metadatenbearbeitung auf Größe, XML und Entity-Deklarationen geprüft. Ohne zusätzliches Passwort bleiben die NZB-Daten unverändert.

Alle 85 automatisierten Tests bestanden. Der lokale Build, die Sprachdateien und die Ad-hoc-Signatur wurden geprüft; die bestehende lokale Bundle-ID blieb erhalten. Die neue Oberfläche und der Speicherdialog wurden nicht in einer Bedienungssitzung geprüft. Die App wurde nicht geöffnet oder neu gestartet. Die Änderungen liegen in der normalen lokalen App unter Build/NZBPort.app; die veröffentlichte Testversion 0.2.4 bleibt unverändert. Kein Commit, Push oder Release.

## Zusätzliche App-Kopien

22. November 2026: Auf Nutzerauftrag liegt eine identische, signaturgeprüfte Kopie des aktuellen lokalen Builds auf dem Datenträger MacSoftware unter Download/NZBPort.app. Künftige App-Änderungen sollen nach erfolgreichem Build auch dorthin übernommen werden. Der Nutzer hat die zunächst gewünschte iCloud-App-Kopie zurückgenommen; sie wird nicht angelegt oder gepflegt. GitHub wird erst bei einem ausdrücklichen Release-Auftrag aktualisiert. Der Nutzer wartet damit vorerst, da möglicherweise weitere Suchdienste hinzukommen. Das separate iOS-Userscript bleibt davon unabhängig.

## Korrigierte automatische Fensterhöhe

23. November 2026: Die bisherige Anpassung addierte gemessenen Scroll-Überlauf zur Fensterhöhe und konnte das Fenster nur vergrößern. Kürzerer Inhalt ließ daher ein zu hohes Fenster mit leerem Platz zurück. Die App misst jetzt den eigentlichen Inhalt innerhalb der Scrollansicht sowie Kopf- und Fußbereich. Aus dieser Gesamthöhe wird die benötigte Fensterhöhe berechnet. Sie kann wachsen und schrumpfen, bleibt auf Mindestgröße und verfügbaren Bildschirmbereich begrenzt und berücksichtigt weiterhin manuelle Größenänderungen bis zum erneuten Öffnen. Schriftgrößen und Fensterbreite sind unverändert.

Alle 85 automatisierten Tests bestanden. Lokaler Build und Signaturprüfung waren erfolgreich; die bestehende lokale Bundle-ID blieb erhalten. Die identische Kopie unter MacSoftware/Download/NZBPort.app wurde aktualisiert und geprüft. Die neue Fensterhöhe wurde noch nicht in der laufenden Oberfläche geprüft; die App wurde für diese Korrektur nicht gestartet. Kein Commit, Push oder Release.

## Getrennte Verbindungseinstellungen

23. November 2026: Der Nutzer bestätigte die korrigierte Fensterhöhe. Die Verbindungseinstellungen sind nun in zwei native GroupBox-Bereiche gegliedert: SABnzbd mit Adresse, Key, Verbindungstest und Kategorienstatus sowie optionale Suchdienste mit getrennten Feldern für Treasure Maps, NewzBay und NinjaCentral. Trennlinien und Anbieternamen ordnen die Keys zu. Der gemeinsame Speichern-Button bleibt außerhalb der Bereiche. Die Speicher- und Suchlogik ist unverändert.

Lokaler Build, Sprachdateien und Signaturprüfung waren erfolgreich. Die identische App-Kopie auf MacSoftware unter Download wurde aktualisiert und geprüft. Für diese reine Umordnung wurden keine weiteren Funktionstests ausgeführt und keine App-Bedienung gestartet. Die neue Gruppierung wurde noch nicht in der laufenden Oberfläche geprüft. Kein Commit, Push oder Release.

## Eigener Kategorienbereich und neue SABnzbd-Kategorien

23. November 2026: Die Kategorienverwaltung wurde aus den Verbindungseinstellungen in eine eigene Ansicht verschoben. „Kategorien …“ ist im Zahnradmenü, im Menü der Menüleisten-App und im App-Menü erreichbar. Dort bleiben Ausblenden, Wiederherstellen, Favoriten und Reihenfolge lokale Anzeigeentscheidungen. Ein Namensfeld mit „In SABnzbd hinzufügen“ legt auf ausdrückliche Nutzeraktion eine neue Kategorie im gespeicherten SABnzbd-Server an. Die bisherige Projektregel, generell keine Kategorien anzulegen, wurde für diesen Nutzerauftrag entsprechend angepasst; Kategorien werden weiterhin nicht gelöscht.

Der Client liest zuerst die aktuelle Kategorienkonfiguration und lehnt bereits vorhandene Namen ab. Zum Anlegen nutzt er einmalig set_config mit section=categories und dem Namen; Ordner, Skript und Priorität werden nicht überschrieben. Neue Kategorien erhalten die Standardwerte von SABnzbd. Danach wird die Kategorienliste neu geladen. Bei unklarem Schreibstatus erfolgt kein automatischer weiterer Versuch. Ein fehlgeschlagener Listenabruf nach bestätigtem Anlegen wird getrennt gemeldet. Die Umsetzung folgt der offiziellen [SABnzbd-API-Dokumentation](https://sabnzbd.org/wiki/configuration/5.1/api) und den Kategorie-Handlern im offiziellen Quellcode.

Alle 97 automatisierten Tests bestanden. Neue Tests prüfen das Anlegen, Duplikate, ungültige Namen, fehlende Konfiguration, Schreib- und Aktualisierungsfehler sowie einen währenddessen eingehenden Link. Lokaler Build, deutsche und englische Sprachdateien, Signatur und identische App-Kopie auf MacSoftware unter Download wurden geprüft. Kein Live-Schreibtest gegen den Nutzer-Server und keine Bedienungssitzung für die neue Ansicht. Keine Veröffentlichung.

## Kategorien auch in SABnzbd löschen

23. November 2026: Der Nutzer bestätigte die Kategorienfunktion als funktionierend und beauftragte zusätzlich das Löschen. Neben Ausblenden beziehungsweise Wieder einblenden steht bei vorhandenen normalen Kategorien nun „Löschen“. Ein Bestätigungsdialog nennt die Kategorie und verlangt „In SABnzbd löschen“. Die Standardkategorie ist geschützt. Ausblenden bleibt eine lokale Anzeigeentscheidung.

Der Client liest die Kategorienkonfiguration, sendet einmalig del_config mit section=categories und keyword mit dem exakten vorhandenen Namen und prüft anschließend über get_config, dass die Kategorie entfernt ist. Die generische Statusantwort allein gilt nicht als Nachweis. Unklare Ergebnisse werden gemeldet und nicht automatisch erneut geschrieben. Erst nach bestätigter Löschung entfernt NZBPort die lokalen Favoriten- und Ausblendungsdaten der Kategorie und aktualisiert die Liste. Laut offiziellem SABnzbd-Kategorie-Handler betrifft die Aktion die Kategorienkonfiguration; Warteschlangenaufträge und heruntergeladene Dateien werden nicht gelöscht.

Alle 109 automatisierten Tests bestanden. Die neuen Prüfungen decken Bestätigung und Abbrechen im Modell, Schutz der Standardkategorie, Entfernung lokaler Anzeigeentscheidungen nach Erfolg, unklare Löschantworten und Fehler bei der anschließenden Aktualisierung ab. Lokaler Build, Sprachdateien, Signatur und identische MacSoftware-Kopie wurden geprüft. Keine Live-Kategorie für einen Test gelöscht und keine Bedienungssitzung für die neue Löschoberfläche durchgeführt. Keine Veröffentlichung.

## Lokale DrunkenSlug-Suche

23. November 2026: Der Nutzer bestätigte auch das Löschen von Kategorien als funktionierend. Auf weiteren Auftrag wurde DrunkenSlug in die Mac-App und das separate iOS-Userscript v2.3.5 aufgenommen. Beide verwenden die Titelsuche unter https://drunkenslug.com/api und den NZB-Abruf anhand der Treffer-ID. DrunkenSlug folgt nach NinjaCentral und wird nur mit gespeichertem eigenem API-Key verwendet. Das gespeicherte Löschen des Keys deaktiviert den Anbieter wieder. Die Mac-App lädt die NZB selbst und übergibt deren Inhalt an SABnzbd; der Suchdienst-Key wird dabei nicht an SABnzbd weitergereicht. Die NZB-Speicherung bleibt ebenfalls verfügbar.

Der anonyme Aufruf von /api?t=caps lieferte HTTP 200 und bestätigte die Titelsuche mit q. Alle 113 automatisierten Swift-Tests bestanden, einschließlich zusätzlicher Tests für DrunkenSlug und der erweiterten Prüfung gespeicherter Keys. Lokaler Build und Signaturprüfung waren erfolgreich; die lokale Bundle-ID blieb erhalten. MacSoftware/Download/NZBPort.app wurde identisch aktualisiert und geprüft. Script-Syntax und simulierte Such-, ID- und Abrufwege bestanden; die Kopien im iCloud-Userscripts-Ordner und unter Downloads sind identisch. Für DrunkenSlug wurde kein echter Key verwendet und keine angemeldete Live-Suche durchgeführt. Keine neue Bedienungssitzung und keine Veröffentlichung.

## Lokale NZBFinder-Suche

23. November 2026: NZBFinder ist in der Mac-App und im separaten iOS-Userscript v2.3.6 als optionaler Anbieter nach DrunkenSlug ergänzt. Beide verwenden die Newznab-XML-Schnittstelle unter https://nzbfinder.ws/api und senden bei Suche und Dateiabruf eine passende App-Kennung. NZBFinder unterstützt die dokumentierten UUID-Treffer-IDs; die bisherigen Anbieter behalten ihre bisherigen ID-Regeln. Ein eigenes API-Key-Feld folgt den bestehenden Speicherregeln. Die NZB-Datei wird weiterhin selbst geladen und geprüft, bevor sie gespeichert oder an SABnzbd übergeben wird.

Der öffentliche Capabilities-Abruf bestätigte HTTP 200 und Titelsuche über q. Der Nutzer erlaubte einen Live-Test mit einem vorübergehenden Key. Die angemeldete Suche wurde mit HTTP 401 und API-Fehler 102 abgelehnt: Für API-Zugriff verlangt NZBFinder eine Premium-Mitgliedschaft. Die normale Ergänzung wurde trotz der Einschränkung des kostenlosen Testkontos beauftragt. Es gab keinen erfolgreichen angemeldeten Such- oder NZB-Abruf und keine SABnzbd-Übergabe. Der Test-Key wurde nicht in Projektdateien, Skripten oder App-Einstellungen gespeichert. Die App und das Script zeigen bei dieser Antwort einen verständlichen Hinweis auf die erforderliche API-Berechtigung.

Alle 119 automatisierten Swift-Tests bestanden. Zusätzliche Tests prüfen UUIDs, die getrennten ID-Regeln, App-Kennung, Dateiabruf, API-Fehler 102 und gespeicherte Keys. Script-Syntax und simulierte vollständige Such- und Abrufwege für NZBFinder und den bisherigen Anbieter DrunkenSlug bestanden. Lokaler Build, Signatur und identische MacSoftware-Kopie wurden geprüft. Die Script-Kopien unter Downloads und im iCloud-Userscripts-Ordner sind identisch. Keine neue Bedienungssitzung und keine Veröffentlichung.

## Release 0.2.5, Build 9

23. November 2026: Auf ausdrücklichen Auftrag für das GitHub-Vorabrelease vorbereitet. Quellen und öffentliche Dokumentation enthalten die Änderungen seit 0.2.4: drei weitere Indexer, NZB-Speicherung, eigener Kategorienbereich mit bestätigtem Anlegen und Löschen in SABnzbd, getrennte Verbindungsbereiche und korrigierte automatische Fensterhöhe. Beide READMEs enthalten zehn Hauptfunktionen und verlinken die vollständigen Feature-Guides. Versionshinweise sind Englisch.

Alle 119 Tests bestanden erneut für den Release-Stand. Die Pakete verwenden die öffentliche Bundle-ID; der normale lokale Build behält seine bestehende Kennung. Apple-Silicon-Architektur, Ad-hoc-Signaturen, ZIP-CRC, DMG-Integrität, die enthaltenen Apps, Applications-Verknüpfung und SHA-256-Prüfsummen wurden geprüft. Quellen, öffentliche Dokumente und Paketinhalt wurden auf echte Zugangsdaten, private Serveradressen, Benutzerpfade und private Kennungen geprüft. Lokale App-Einstellungen sind nicht enthalten. Die App wurde für diese Releaseprüfung nicht gestartet. Prüfnachweise liegen lokal unter Build/Verification/0.2.5; Pakete und englische Versionshinweise unter Build/Release/0.2.5. Das iOS-Userscript bleibt ein separates lokales Script und ist kein Bestandteil des Mac-Pakets.

## Lokale Videothek-Ergänzung

24. November 2026: Videothek.io ist als optionaler Suchdienst nach NZBFinder ergänzt. Ein eigenes API-Key-Feld folgt den bisherigen Speicherregeln; ohne gespeicherten Key wird der Anbieter übersprungen. Suche und NZB-Abruf verwenden https://videothek.io/api und eine ehrliche NZBPort-Kennung. Streng geprüfte 32-stellige Hex-IDs und UUIDs werden unterstützt; diese Formate sind für Videothek nur mit synthetischen Antworten geprüft. Der öffentliche Capabilities-Abruf bestätigt die Titelsuche. Laut [Anbieterdokumentation](https://videothek.io/wiki?article=api-und-feeds) benötigt die tatsächliche API-Nutzung Premium und ein zugelassenes Tool. Die Ergänzung wurde auf Nutzerwunsch zunächst ohne Premium vorbereitet; eine angemeldete Suche und ein NZB-Abruf wurden nicht getestet.

Alle 122 automatisierten Swift-Tests bestanden. Lokaler Build und Signaturprüfung waren erfolgreich; die bisherige lokale Bundle-ID blieb erhalten. Die identische App-Kopie unter MacSoftware/Download wurde aktualisiert und geprüft. Die App wurde nicht gestartet und die neue Zeile nicht in einer Bedienungssitzung geprüft. Keine Veröffentlichung.

Das separate iOS-Userscript v2.3.7 enthält Videothek ebenfalls als letzten optionalen Anbieter. Die vorhandene iCloud-Kopie war die Grundlage; die fehlende Downloads-Kopie wurde daraus wiederhergestellt. Beide Dateien sind identisch. Syntax und statische Prüfungen bestanden. Die simulierten Anfrageabläufe konnten nicht erfolgreich ausgeführt werden; eine Prüfung auf dem iPhone steht aus. Die Kennung für die Freigabe lautet `NZBPort/nzb-load/2.3.7 (NZB link search; iOS Userscripts)`.

## Lokale Oberflächenergänzungen für macOS 27

24. November 2026: Der Zahnradknopf ist unter macOS 27 ein eigener SwiftUI-Button mit nativem Liquid-Glass-Hintergrund. Beim Darüberfahren wächst er auf 118 Prozent, beim Drücken schrumpft er auf 82 Prozent; eine Federanimation verbindet die Zustände. Eine Akzentumrandung und ein Lichtschein verstärken die Rückmeldung. Bei reduzierter Bewegung entfallen Skalierung und Animation. Der Button öffnet über NSHostingMenu weiterhin ein natives Menü mit den bisherigen Aktionen und Untermenüs. Sein unsichtbarer Positionsanker nimmt keine Mausereignisse an. Die vorherige Ergänzung am nativen Menu hatte keine deutlich sichtbare Federbewegung ergeben. Das Kategorie-Suchfeld verwendet weiterhin interaktives reguläres Glas. Unter macOS 26 bleibt die bisherige Darstellung erhalten.

Favorisierte Kategorien lassen sich unter macOS 27 mit den neuen SwiftUI-Reorder-Funktionen ziehen. Nur angezeigte Favoriten ändern ihre lokal gespeicherte Reihenfolge. Verborgene und nicht verfügbare Favoriten behalten ihre Plätze; Ablegen auf sich selbst ändert nichts. Die Pfeile bleiben für Tastaturbedienung und macOS 26 erhalten. Es werden keine Kategorien in SABnzbd geändert.

Zahnrad, Kategoriebuttons, Kategorie-Suchfeld und Hinweiskarten berücksichtigen unter macOS 27 die Systemeinstellung „Ränder anzeigen“. Hinweiskarten verwenden konzentrische Rundungen relativ zur umgebenden Containerform; unter macOS 26 bleibt der bisherige feste Radius erhalten. Die verwendete ConcentricRectangle-API ist bereits ab macOS 26 verfügbar; ihr Einsatz ist hier zur Wahrung der bisherigen Darstellung auf macOS 27 begrenzt.

Alle 125 automatisierten Tests bestanden, einschließlich Favoritenreihenfolge und Speicherung, verschiedener gerenderter Knopfzustände sowie erhaltener nativer Menüaktionen und Untermenüs. Ruhe-, Hover- und Druckzustand wurden ohne sichtbares Fenster gerendert und visuell verglichen. Dies prüft die dargestellten Zustände, nicht die vollständige zeitliche Animation. Bildnachweise liegen lokal unter Build/Verification/interactive-glass; macos27-tests.log und interactive-glass-build.log halten die Prüfungen fest. Die Systemeinstellung für Umrandungen wurde nicht verändert. Ein echter Drag-and-drop-Vorgang und die endgültige Klickanimation wurden nach dem Nutzerwunsch nach Hintergrundarbeit nicht erneut im Vordergrund bedient.

Lokaler Build, Sprachdateien, Ad-hoc-Signatur und identische MacSoftware-Kopie unter Download wurden geprüft. Die lokale Bundle-ID blieb erhalten. Die App wurde für den letzten Build nicht neu gestartet oder in den Vordergrund geholt. Keine Veröffentlichung.

## Suchfeld geprüft, Aktualisieren-Button erweitert

24. November 2026: Nach ausdrücklicher Zustimmung des Nutzers wurde „Kategorie suchen“ in der laufenden App unter macOS 27 beim Darüberfahren und Anklicken aufgenommen. Der laufende Prozess war nach dem Build vom 24. November um 07:04:20 gestartet. In der Aufnahme ändern sich die Glasreflexe leicht; eine deutliche Federbewegung wie am Zahnrad ist nicht erkennbar. Die frühere Beschreibung eines deutlich sichtbaren neuen Suchfeldeffekts ist damit nicht bestätigt. Ein auf das Suchfeld zugeschnittener Mitschnitt und die Bildfolge liegen lokal unter Build/Verification/searchfield; die vollständige Fensteraufnahme wurde gelöscht. Kein Download wurde gesendet und keine Einstellung geändert.

Auf weiteren Nutzerauftrag verwendet der Aktualisieren-Button rechts neben „Kategorie wählen“ unter macOS 27 denselben eigenen Glas-Buttonstil wie das Zahnrad. Der Kategorienabruf und die Sperre während laufender Aktionen bleiben erhalten; unter macOS 26 bleibt der bisherige Stil. Ruhe-, Hover- und Druckzustand wurden für beide Symbole im Hintergrund gerendert und visuell verglichen. Der gezielte Rendering-Test bestand mit zwei Testfällen. Ein tatsächlicher Klick auf den neuen Aktualisieren-Button wurde nicht ausgeführt; die zeitliche Animation dieses Buttons ist damit nicht separat bestätigt. Der neue Build und seine Signatur sowie die identische Kopie unter MacSoftware/Download wurden geprüft. Kein erneuter vollständiger Testlauf und keine Veröffentlichung; die laufende App wurde nicht neu gestartet.

## Zweiter Refresh-Button in der Kategorienverwaltung

24. November 2026: Die Hintergrundaufnahme der laufenden Ansicht zeigte den weiteren Refresh-Button auf „Deine Kategorien“. Dieser verwendete im vorherigen Stand noch den normalen Stil; nur der Button neben „Kategorie wählen“ war zuvor angepasst. Auch der zweite Button nutzt jetzt unter macOS 27 denselben interaktiven Glas-Buttonstil wie das Zahnrad. Seine Aktion und Sperrbedingungen sind unverändert.

Nach ausdrücklicher Zustimmung zur sichtbaren Bedienung wurde die App nach dem Build neu gestartet, „Deine Kategorien“ geöffnet und der tatsächliche Button beim Darüberfahren und Anklicken aufgenommen. Die Bildfolge zeigt Kreis, Vergrößerung, Druckbewegung und Rückbewegung am echten Button. Der Klick rief nur die Kategorien ab; es wurde keine Kategorie geändert und kein Download gesendet. Der zugeschnittene Mitschnitt liegt unter Build/Verification/category-refresh; die vollständige Fensteraufnahme wurde entfernt. Build, Signatur und identische MacSoftware-Kopie unter Download wurden geprüft. Die bisherigen Rendering-Tests des unveränderten gemeinsamen Stils wurden nicht erneut ausgeführt. Keine Veröffentlichung.

## Favoriten-Ziehen und Drop-Markierung korrigiert

24. November 2026: Die zunächst verwendete Reorder-Anbindung startete beziehungsweise übernahm den Drag in der tatsächlichen Kategorienansicht nicht zuverlässig. Sie wurde unter macOS 27 durch eine direkte Ziehgeste der Favoritenzeile ersetzt. Die gemessene Zeilenhöhe bestimmt die neue Position; geändert und gespeichert wird die lokale Reihenfolge erst beim Loslassen. Die Pfeile und der bisherige macOS-26-Weg bleiben erhalten. Es wird nichts in SABnzbd geändert.

Die gelbe Fensterumrandung war die hängen gebliebene Datei-/Link-Drop-Markierung. Ein DropDelegate setzt sie beim Verlassen und Ablegen zurück; zusätzlich wird sie bei Ansichtswechsel und Deaktivierung der App entfernt. Der bisherige Datei-/Link-Import bleibt bestehen.

Im zuletzt gebauten und laufenden Stand wurde mit Nutzerzustimmung ein echter Maus-Drag geprüft: „serien, filme“ änderte sich sichtbar und in den gespeicherten Einstellungen zu „filme, serien“. Dabei erschien keine gelbe Drop-Umrandung. Beide vorübergehend gesetzten Favoriten wurden anschließend per Oberfläche entfernt, entsprechend dem vorgefundenen Zustand ohne Favoriten. Build und Signatur sowie die identische MacSoftware-Kopie unter Download wurden geprüft. Auf ausdrücklichen Nutzerwunsch keine weiteren wiederholten Prüfungen oder neuen vollständigen Testläufe. Kein Commit, Push oder Release.

## Native Scrollkanten

24. November 2026: Der ScrollView im Hauptfenster verwendet unter macOS 27 ausdrücklich Apples harten Scrollkanteneffekt oben und unten. Unter macOS 26 bleibt die automatische Darstellung erhalten. Die API scrollEdgeEffectStyle und der Stil hard sind bereits ab macOS 26 verfügbar; die Auswahl ist hier auf macOS 27 begrenzt. Der Effekt ist eine native Systemfunktion, keine zusätzliche selbst gezeichnete Animation.

Der lokale Build und seine Signatur sowie die identische Kopie auf MacSoftware unter Download wurden geprüft. Die App wurde nach anfänglicher Zustimmung zur sichtbaren Prüfung neu gestartet und die Verbindungseinstellungen geöffnet. Die eigentliche Scrollaufnahme wurde nicht durchgeführt, nachdem der Nutzer erneut ausschließlich Hintergrundbedienung verlangte. Eine sichtbare Wirkung der Scrollkante ist deshalb nicht bestätigt. Kein weiterer Funktionstest, keine Änderung gespeicherter Einstellungen und keine Veröffentlichung.

## Videothek-Prüfung und Veröffentlichung des Quellstands

24. November 2026: Auf Nutzerauftrag werden der aktuelle Quellstand nach Release 0.2.5 und das separate iOS-Userscript für die Anbieterprüfung zugänglich gemacht. Die damalige Skriptfassung wurde für die Anbieterprüfung veröffentlicht. Die Mac-App bettet das Script weiterhin nicht ein. Der Newznab-Client verwendet bei allen seinen Such- und Dateiabrufen die feste Kennung `NZBPort/0.2.5 (+https://github.com/Schrotty74/NZBPort)`. Die Script-Kennung bleibt `NZBPort/nzb-load/2.3.7 (NZB link search; iOS Userscripts)`.

Eine einmalige direkte HTTPS-Anfrage an Videothek mit dem vom Nutzer bereitgestellten Key, t=caps und der aus dem Quellcode gelesenen Mac-Kennung lieferte HTTP 200 und eine XML-Capabilities-Antwort. Diese Anfrage lief als separates lokales Prüfprogramm, nicht als Bedienung der Mac-App. Sie bestätigt keine Such- oder Downloadberechtigung. Es wurde kein zweiter Live-Aufruf und kein iPhone-Netzwerkmitschnitt ausgeführt. Der Key wurde nur im Arbeitsspeicher verwendet, nicht in Dateien oder App-Einstellungen gespeichert und nicht ausgegeben. Der bereinigte Nachweis enthält nur Zeitpunkt, Kennung, Status und XML-Wurzelelement.

Alle 125 automatisierten Tests bestanden für den aktuellen Quellstand, einschließlich der erwarteten Mac-Kennung bei Videothek-Suche und Dateiabruf. Script-Syntax, Quellstand und Script wurden auf private Daten geprüft. Das Script enthält keine ursprüngliche Lizenz- oder Herkunfts-URL-Metadaten; die vorhandene Autorenangabe wurde beibehalten. Die READMEs unterscheiden den neuen Quellstand von den unveränderten Downloadpaketen des Releases 0.2.5. Es wird für diese Quellenbereitstellung kein neues Release oder Tag erstellt.

## Videothek verwendet 40-stellige Hex-IDs

Videothek hat das Format seiner Treffer-IDs bestätigt. Mac-App und iOS-Skript v2.3.8 akzeptieren diese IDs für Videothek, auch aus geprüften Abrufadressen in `link` und `enclosure`. Die Prüfungen mit simulierten Antworten bestanden. Die Mac-App wurde lokal gebaut, ihre Kopie auf MacSoftware geprüft und das Skript unter Downloads und in iCloud aktualisiert. Ein weiterer Live-Abruf steht aus.

Laut Videothek gilt die Freigabe für die festen Präfixe `NZBPort/` und `NZBPort/nzb-load/`. Künftige Versionsnummern sind von derselben Freigabe abgedeckt.

## Testversion 0.2.6, Build 10

Dieses Vorabrelease ergänzt Videothek und die lokalen Änderungen unter macOS 27 für Zahnrad, Aktualisieren-Knöpfe, Favoritensortierung und Scrollkanten. Die Mac-Kennung lautet `NZBPort/0.2.6 (+https://github.com/Schrotty74/NZBPort)`. Videothek hat die Mac-App und das separate iOS-Skript über ihre festen Präfixe freigegeben.

DrunkenSlug lieferte 40-stellige Hex-IDs. Der direkte Live-Abruf folgte einer Weiterleitung zum eigenen NZB-Endpunkt und lieferte eine gültige NZB. NZBFinder akzeptiert zusätzlich 40 Hex-Zeichen, was mit simulierten Antworten geprüft wurde. Die Live-Suche war mit dem vorhandenen Konto nicht möglich. Videothek lieferte beim letzten Suchtest API-Fehler 500. NewzBay wurde mangels Zugang ausgelassen.

Für den Release-Stand bestanden 127 automatisierte Swift-Tests. Build, Signaturen, Apple-Silicon-Architektur, ZIP, DMG und Prüfsummen wurden geprüft. Das separate iOS-Skript wurde auf v2.3.9 erhöht. Eine neue Bedienungsprüfung fand für diesen Build nicht statt.

## Aktuelles iPhone-Userscript

Seit 25. November 2026 liegt die neue Fassung unter `Userscripts/NZBPort.user.js`. Sie übernimmt kompatible Einstellungen aus einer JSON-Sicherung der früheren Fassung. In Version 0.1.2 reagieren NZBlnk und „An SABnzbd senden“ auf NewzBay nur auf Benutzertipps. Der Nutzer hat die Version am iPhone getestet und bestätigt. Die Freigabe bei Videothek bleibt an denselben technischen Präfix gebunden.
