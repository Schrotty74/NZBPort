# NZBPort

[English](README.md) · [Downloads](https://github.com/Schrotty74/NZBPort/releases)

> Aktuelle Testversion: **0.2.9**. [DMG oder ZIP herunterladen](https://github.com/Schrotty74/NZBPort/releases/tag/v0.2.9).

Zum separaten [iOS-Userscript](Userscripts/NZBPort.user.js) gibt es eine [deutsche Anleitung](Userscripts/README.de.md).

NZBPort ist eine macOS-Menüleisten-App, die `nzblnk:`-Links und NZB-Dateien öffnet und Aufträge an SABnzbd übergibt. Du kannst die Kategorie selbst wählen oder aus dem Releasetitel erkennen lassen. NZB-Dateien lassen sich auch lokal speichern.

## Funktionen

- **NZBlnk-Links und NZB-Dateien öffnen**. NZB-Dateien lassen sich auch lokal speichern, einschließlich eines eventuell vorhandenen Link-Passworts.
- **Downloadordner überwachen**. Neue NZB-Dateien verarbeiten und die Originale in den Papierkorb legen, sobald SABnzbd sie angenommen hat.
- **Zehn Suchdienste zur Auswahl**, darunter Easynews. In den Verbindungseinstellungen kannst du sie einzeln testen, umsortieren und ein- oder ausschalten.
- **Kategorie erkennen und automatisch senden**. Serien, Spielen, Filmen und sonstigen Titeln SABnzbd-Kategorien zuordnen oder eigene Titelregeln anlegen. Gibt es keine verfügbare Zuordnung, öffnet sich die manuelle Auswahl.
- **SABnzbd-Kategorien verwalten**. Kategorien in SABnzbd anlegen oder löschen. Favoriten und ausgeblendete Kategorien verwaltest du lokal in NZBPort.
- **Priorität festlegen, Aufträge pausiert übergeben und wartende Links und Dateien verwalten**: Einträge vor der Übergabe ansehen und einzeln entfernen.
- **Downloads im Blick behalten**: Fortschritt, Kategorien und Verlauf sehen, einzelne Aufträge oder die ganze Warteschlange pausieren und fortsetzen.
- **SABnzbd-Status in der Menüleiste sehen** und macOS-Mitteilungen bei fertigen oder fehlgeschlagenen Downloads erhalten. Beim automatischen Versand bestätigt NZBPort die Zielkategorie kurz im Fenster.
- **Einstellungen sichern und wiederherstellen**. Die JSON-Sicherung enthält auch Titelregeln, die Suchreihenfolge und gespeicherte Zugangsdaten. Vor dem Wiederherstellen zeigt NZBPort die wichtigsten Angaben zur Sicherung.
- **Bei der Anmeldung starten** und NZBPort direkt in der Menüleiste bereithalten.
- **SABnzbd-Verbindung prüfen**. Änderst du Adresse oder API-Key, setzt NZBPort das Prüfergebnis zurück.
- **Einstellungen in beiden Menüs finden**. Das Menüleistensymbol und das Zahnrad verwenden dieselben Untermenüs für Einstellungen und „Über NZBPort“.

[Alle Funktionen im Detail](docs/FEATURES.de.md).

## Bildschirmfotos

| Hauptfenster | Verbindungseinstellungen |
| --- | --- |
| ![NZBPort-Hauptfenster](docs/screenshots/nzbport-main.png) | ![NZBPort-Verbindungseinstellungen](docs/screenshots/nzbport-settings.png) |

Die Screenshots zeigen eine frühere NZBPort-Version. Die private Serveradresse im ersten Screenshot wurde unkenntlich gemacht.

## Voraussetzungen und Installation

- Ein Mac mit Apple Silicon und macOS 26 oder neuer.
- Ein laufender SABnzbd-Server und dessen vollständiger API-Key. Für private Suchdienste kannst du deine Zugangsdaten hinterlegen.

Lade die DMG oder ZIP unter [Releases](https://github.com/Schrotty74/NZBPort/releases) herunter. Öffne die DMG und ziehe NZBPort in „Applications“, oder entpacke die ZIP und verschiebe die App nach „Programme“. Die App ist ad hoc signiert und nicht von Apple notarisiert. Falls macOS den ersten Start blockiert, folge den Gatekeeper-Schritten unten.

### Gatekeeper: NZBPort zum ersten Mal öffnen

Erlaube nur einen Build aus den offiziellen [NZBPort-GitHub-Releases](https://github.com/Schrotty74/NZBPort/releases), dem du vertraust.

1. Verschiebe die App nach „Programme“ und versuche einmal, `NZBPort.app` normal zu öffnen, damit macOS den blockierten Start registriert.
2. Öffne **Systemeinstellungen → Datenschutz & Sicherheit** und scrolle zum Bereich **Sicherheit**.
3. Klicke bei NZBPort auf **Dennoch öffnen**.
4. Bestätige mit **Öffnen** und authentifiziere dich, falls macOS dich dazu auffordert.

**Dennoch öffnen** erscheint nur für begrenzte Zeit nach dem blockierten Startversuch. Fehlt die Schaltfläche, versuche erneut, die App zu öffnen, und kehre zu diesen Einstellungen zurück. Dadurch wird eine Ausnahme für NZBPort angelegt; Gatekeeper bleibt systemweit aktiviert.

Siehe auch [Apples Anleitung zum sicheren Öffnen von Apps](https://support.apple.com/de-de/102445).

## Einrichten

1. Öffne NZBPort und trage die SABnzbd-Adresse und den vollständigen API-Key ein.
2. Prüfe die Verbindung und speichere die Einstellungen.
3. Wähle „Als Link-App verwenden“, um NZBPort für `nzblnk:`-Links zu registrieren.
4. Falls ein Browser-Userscript die Links bereits abfängt, deaktiviere es auf diesem Mac.

## Datenschutz und Suchdienste

SABnzbd-Adresse und API-Key werden lokal und unverschlüsselt in den App-Einstellungen gespeichert. Die App verwendet keinen Schlüsselbund. Der API-Key wird im POST-Inhalt an den eingestellten SABnzbd-Endpunkt gesendet. HTTP wird unterstützt; nutze für fremde Netze HTTPS oder ein vertrauenswürdiges VPN.

NZBIndex, NZBKing und BinSearch erhalten die Suchkennung des Links. NZBIndex erhält zusätzlich die Newsgroups. Standardmäßig sucht NZBPort zuerst bei diesen drei Diensten, danach bei Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder, Videothek und Easynews. Im Bereich „Suchdienste“ findest du die Suchreihenfolge, den Test pro Anbieter und das Schlüsselsymbol für die Zugangsdaten. NZBPort überspringt deaktivierte Dienste und Dienste ohne die benötigten Zugangsdaten. Newznab-Anbieter erhalten den Releasetitel und ihren jeweiligen API-Key. Bei Easynews sucht die App mit der Suchkennung aus dem Link und meldet sich per HTTPS mit Benutzername und Passwort an. Beim Speichern legt NZBPort die Zugangsdaten lokal und unverschlüsselt ab. Ein direkter angemeldeter Test bei NinjaCentral lieferte einen passenden Treffer und eine gültige NZB-Datei. Bei NewzBay folgt die App für den NZB-Abruf einer HTTPS-Weiterleitung zum Download-Endpunkt desselben Anbieters. Bei DrunkenSlug waren eine Live-Suche und der NZB-Abruf mit einer 40-stelligen Hex-ID erfolgreich. Für API-Zugriff auf NZBFinder ist eine Premium-Mitgliedschaft erforderlich; ein kostenloses Konto kann HTTP 401 mit API-Fehler 102 liefern.

NZBPort lädt Treffer eingerichteter Indexer selbst und übergibt die NZB-Datei an SABnzbd. SABnzbd erhält außerdem den Titel, die gewählte Kategorie und das optionale Archivpasswort. Beim Speichern einer NZB-Datei trägt NZBPort das Link-Passwort unverändert als NZB-Metadatum ein. Den SABnzbd-Key erhält nur der von dir eingestellte SABnzbd-Server. Die Suche hängt von der Verfügbarkeit und den Bedingungen der Anbieter ab. Die HTML-Ausweichsuche kann ausfallen, wenn ein Anbieter seine Seiten ändert oder automatisierte Zugriffe sperrt. Zugangssperren und CAPTCHAs werden nicht umgangen.

Das Speichern einer NZB-Datei ist auch möglich, wenn SABnzbd nicht eingerichtet oder nicht erreichbar ist. Importierte NZB-Dateien kannst du als Kopie speichern. Der aktuelle Link oder die Datei bleibt erhalten, wenn du den Speicherdialog abbrichst oder das Speichern fehlschlägt. Du kannst es erneut versuchen oder eine andere Aktion wählen.

Der Anwendungscode wurde für dieses Projekt in Swift neu geschrieben: Link-Auswertung, Suchdienste, HTML-Parser, SABnzbd-Client und lokaler Kategorienfilter. Die App enthält keinen fremden Anwendungscode und keine externen Paketabhängigkeiten. Sie verwendet Apples Swift-Standardbibliothek und Systemframeworks wie Foundation, AppKit und SwiftUI. Auch das Markenzeichen wurde für dieses Projekt erstellt.

## Bauen

Benötigt wird Xcode mit macOS-26-SDK oder neuer, einschließlich der Icon-Composer-Asset-Kompilierung. Wähle es mit `xcode-select` aus. Externe Pakete sind nicht erforderlich.

```sh
swift test
zsh Scripts/build.sh
```

Die App entsteht unter `Build/NZBPort.app` und wird lokal ad hoc signiert. Das Build-Skript leitet den Projektordner aus seinem eigenen Speicherort ab und entfernt Debugsymbole aus der verteilten Programmdatei. Es installiert keine Zertifikate und veröffentlicht nichts.

| Bereich | Aufgabe |
| --- | --- |
| `Sources/RelayCore` | Link-Auswertung, Suchdienste, SABnzbd-API und Kategorienfilter |
| `Sources/NZBRelay` | App-Lebenszyklus, Menüleiste und Zustand |
| `Sources/NZBRelay/UI` | Ansichten und Einstellungen |
| `Sources/NZBRelay/Localization` | Gespeicherte Sprachwahl und natives Sprachmenü |
| `Sources/RelayCore/Resources` | Deutsche und englische Texte für Oberfläche und Fehler |
| `Sources/NZBRelay/Theme` | Erscheinungsbild und native Glass-Bedienelemente |
| `Resources/NZBPort.icon` | Bearbeitbares Icon-Composer-Dokument |
| `Scripts` | App-Build und Erzeugung des eigenen Markenzeichens |
| `Tests` | Tests für Parser, Suchauflösung und API-Verträge |

Die internen Targets heißen weiterhin `NZBRelay`; der sichtbare App-Name lautet NZBPort. Die Einstellungen sind der Bundle-ID der App zugeordnet.

## Lizenz

GNU General Public License Version 3. Siehe [LICENSE](LICENSE).
