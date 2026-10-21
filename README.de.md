# NZBPort

[English](README.md) · [Downloads](https://github.com/Schrotty74/NZBPort/releases)

NZBPort ist eine kleine macOS-Menüleisten-App, die `nzblnk:`-Links öffnet und Downloads an SABnzbd übergibt. Nach deiner Kategorieauswahl sucht sie bei Bedarf nacheinander über NZBIndex, NZBKing und BinSearch. Sobald SABnzbd die Übergabe bestätigt, schließt sich das Fenster. Die App bleibt in der Menüleiste erreichbar.

## Voraussetzungen und Installation

- Ein Mac mit Apple Silicon und macOS 26 oder neuer.
- Ein laufender SABnzbd-Server und dessen vollständiger API-Key.

Lade die DMG oder ZIP unter [Releases](https://github.com/Schrotty74/NZBPort/releases) herunter. Öffne die DMG und ziehe NZBPort in „Applications“, oder entpacke die ZIP und verschiebe die App nach „Programme“. Die App ist ad hoc signiert und nicht von Apple notarisiert. macOS kann sie deshalb blockieren. Prüfe den Quellcode und erlaube das Öffnen in „Datenschutz & Sicherheit“ nur, wenn du diesem Build vertraust.

## Einrichten

1. Öffne NZBPort und trage die SABnzbd-Adresse und den vollständigen API-Key ein.
2. Prüfe die Verbindung und speichere die Einstellungen.
3. Wähle „Als Link-App verwenden“, um NZBPort für `nzblnk:`-Links zu registrieren.
4. Falls ein Browser-Userscript die Links bereits abfängt, deaktiviere es auf diesem Mac.

Die Oberfläche ist deutsch. Kopierte Links kannst du über „NZBlnk aus Zwischenablage“ öffnen. Beim Öffnen eines Links werden die Kategorien von SABnzbd neu geladen. In den Einstellungen kannst du Kategorien ausblenden und wieder einblenden. Das betrifft nur die Anzeige in NZBPort; SABnzbd bleibt unverändert. Neue Kategorien erscheinen automatisch. Mehrere Links werden nacheinander bearbeitet.

Im App-Menü und im Zahnradmenü wählst du zwischen System, Hell und Dunkel sowie einem systemgesteuerten, transparenten oder deckenden Fensterhintergrund. Die Bedienelemente nutzen natives Liquid Glass. Das Icon-Composer-Dokument unterstützt die Systemdarstellungen des App-Icons.

## Vom Link zum Download

1. Der Browser übergibt einen `nzblnk:`-Link an die registrierte macOS-App. Zuvor kann der Browser eine Bestätigung verlangen.
2. NZBPort liest Suchkennung (`h`), Titel (`t`), optionales Passwort (`p`) und wiederholte Gruppenfelder (`g`). Prozentkodierter Text wird unterstützt; abgekürzte `a.b.`-Gruppen werden für NZBIndex ausgeschrieben.
3. Die App ruft die aktuellen SABnzbd-Kategorien ab und berücksichtigt deine lokal ausgeblendeten Kategorien. Über das Suchfeld kannst du die Kategoriebuttons nach Namen filtern.
4. Mit der Kategorieauswahl beginnt die Suche. Zuerst wird die öffentliche JSON-API von NZBIndex ohne zusätzlichen Such-API-Key verwendet. Schlägt die Suche fehl, folgen NZBKing und BinSearch mit ihren öffentlichen Suchantworten.
5. NZBPort übergibt Downloadadresse, Titel, gewählte Kategorie und optionales Archivpasswort an SABnzbd. Den Download übernimmt SABnzbd; NZBPort lädt selbst keine Usenet-Artikel.
6. Nach einer bestätigten Übergabe schließt sich das Fenster oder der nächste wartende Link erscheint. Bei einem Fehler bleibt die Meldung sichtbar. Läuft eine Übergabe in ein Timeout, prüfe vor einem neuen Versuch die SABnzbd-Warteschlange, um doppelte Aufträge zu vermeiden.

Mehrere unterschiedliche Trefferkennungen lehnt der NZBIndex-Provider ab; anschließend geht die Ausweichsuche weiter. Die HTML-Provider verwenden den ersten unterstützten Treffer ihrer Antwort. Suchtreffer garantieren weder Inhalt noch Verfügbarkeit. Die App legt keine SABnzbd-Kategorien an, löscht keine Kategorien, verwaltet keine Usenet-Zugänge und ändert den globalen Pausenzustand von SABnzbd nicht.

## Datenschutz und Suchdienste

SABnzbd-Adresse und API-Key werden lokal und unverschlüsselt in den App-Einstellungen gespeichert. Die App verwendet keinen Schlüsselbund. Der API-Key wird im POST-Inhalt an den eingestellten SABnzbd-Endpunkt gesendet. HTTP wird unterstützt; nutze für fremde Netze HTTPS oder ein vertrauenswürdiges VPN.

Die Suchdienste erhalten die Suchkennung des Links; NZBIndex erhält zusätzlich dessen Gruppen. Titel, Archivpasswort und SABnzbd-Key gehören nicht zu den Suchanfragen. Titel und optionales Passwort werden zusammen mit der gewählten Kategorie an SABnzbd übergeben. Verfügbarkeit und Nutzung hängen von den externen Diensten und deren Bedingungen ab. Die HTML-Ausweichsuche kann bei Seitenänderungen oder einer Sperre automatisierter Zugriffe ausfallen. Zugangssperren und CAPTCHAs werden nicht umgangen.

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
| `Sources/NZBRelay/Theme` | Erscheinungsbild und native Glass-Bedienelemente |
| `Resources/NZBPort.icon` | Bearbeitbares Icon-Composer-Dokument |
| `Scripts` | App-Build und Erzeugung des eigenen Markenzeichens |
| `Tests` | Tests für Parser, Suchauflösung und API-Verträge |

Die internen Targets heißen weiterhin `NZBRelay`; der sichtbare App-Name lautet NZBPort. Die Einstellungen sind der Bundle-ID der App zugeordnet.

## Lizenz

GNU General Public License Version 3. Siehe [LICENSE](LICENSE).
