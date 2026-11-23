# Funktionen von NZBPort

[Zurück zur README](../README.de.md) · [English](FEATURES.md)

## Links und Dateien öffnen

- **NZBlnk-Links:** Öffne einen Link aus Safari, füge ihn über **NZBlnk aus Zwischenablage** ein oder ziehe ihn ins Fenster.
- **macOS-Link-Zuordnung:** NZBPort prüft beim Start und beim Aktivieren, welche App NZBlnk-Links öffnet. Ist NZBPort bereits als Standard eingetragen, zeigt der Button **Als Link-App eingerichtet**.
- **NZB-Dateien:** Öffne Dateien über die Dateiauswahl, über **Öffnen mit** im Finder oder per Drag-and-drop. Pro Datei sind bis zu 16 MiB erlaubt. Für die aktuelle und alle wartenden NZB-Dateien gilt zusammen ein Limit von 64 MiB.
- **NZB speichern:** Speichere die aktuelle NZB-Datei an einem Ort deiner Wahl, auch wenn SABnzbd nicht eingerichtet oder nicht erreichbar ist. Importierte NZB-Dateien kannst du als Kopie speichern. Bei einem Link mit Archivpasswort trägt NZBPort genau dieses Passwort als NZB-Metadatum ein. Brichst du den Speicherdialog ab oder schlägt das Speichern fehl, bleibt der aktuelle Eingang verfügbar.
- **Wartende Links und Dateien:** NZBPort bearbeitet die Eingänge nacheinander. Die Liste zeigt, was als Nächstes dran ist. Du kannst einzelne Einträge vor der Übergabe entfernen; der aktuelle Auftrag bleibt erhalten.

## Kategorie wählen und Auftrag übergeben

- **Kategorien abrufen:** NZBPort lädt die aktuellen SABnzbd-Kategorien beim Start, beim Öffnen eines Auftrags und auf Wunsch auch manuell. Der Abruf beim Start läuft im Hintergrund.
- **Kategorie finden:** Filtere die Kategoriebuttons vor der Übergabe nach Namen.
- **Kategorie anlegen:** Auf der eigenen Seite **Kategorien** kannst du eine Kategorie in SABnzbd anlegen.
- **Kategorie löschen:** Das Löschen einer vorhandenen Kategorie in SABnzbd musst du bestätigen. Die Standardkategorie ist geschützt. Dabei ändert sich die Kategorienkonfiguration; wartende Aufträge und bereits geladene Dateien bleiben erhalten.
- **Lokale Kategorieeinstellungen:** Auf der Seite **Kategorien** kannst du Kategorien ausblenden oder wieder einblenden und Favoriten anheften und sortieren. Diese Änderungen gelten nur in NZBPort. Neue Kategorien von SABnzbd erscheinen automatisch.
- **Priorität:** Wähle vor der Übergabe Niedrig, Normal, Hoch oder Sofort. Mit **Pausiert hinzufügen** legst du einen Auftrag an, ohne ihn zu starten.
- **Titel und Archivpasswort:** NZBPort übergibt den Titel und ein im NZBlnk-Link enthaltenes Archivpasswort zusammen mit der gewählten Kategorie an SABnzbd.
- **Rückmeldung zur Übergabe:** Sobald SABnzbd den Auftrag bestätigt, zeigt NZBPort den nächsten Eingang oder schließt das Fenster und bleibt in der Menüleiste. Fehler bei der Verbindung oder Übergabe zeigt die App an.
- **Duplikatwarnung:** Bei erkannten Wiederholungen innerhalb von zehn Minuten bittet NZBPort um Bestätigung, auch nach einer unklaren Übertragung. Für die Prüfung bleiben nur Hashes und Zeitstempel im Arbeitsspeicher. Wenn unklar ist, ob SABnzbd den Auftrag angenommen hat, prüfe vor einem neuen Versuch die Warteschlange.

## Suchdienste

- **Öffentliche Suche:** NZBIndex, NZBKing und BinSearch werden in dieser Reihenfolge abgefragt. NZBIndex verwendet seine öffentliche API und benötigt keinen Such-API-Key.
- **Optionale Indexer:** Wenn die öffentliche Suche nichts findet, fragt NZBPort Anbieter mit gespeichertem API-Key der Reihe nach ab. Jeder Dienst hat ein eigenes optionales API-Key-Feld in den Verbindungseinstellungen. Bei einem gültigen Treffer endet die Suche. Fehler, unpassende Titel oder mehrdeutige API-Treffer lassen die Suche beim nächsten Anbieter weiterlaufen.

| Reihenfolge | Anbieter | Such-API-Key |
| --- | --- | --- |
| 1 | NZBIndex | Nein, öffentliche API |
| 2 | NZBKing | Nein |
| 3 | BinSearch | Nein |
| 4 | Treasure Maps | Optional, separat gespeichert |
| 5 | NewzBay | Optional, separat gespeichert |
| 6 | NinjaCentral | Optional, separat gespeichert |
| 7 | DrunkenSlug | Optional, separat gespeichert |
| 8 | NZBFinder | Optional, separat gespeichert; API-Zugriff erfordert Premium-Mitgliedschaft |

- **Anfragen an Anbieter:** Ein eingerichteter Anbieter erhält den Releasetitel und nur seinen eigenen API-Key. Die Keys werden erst nach dem ausdrücklichen Speichern lokal und unverschlüsselt abgelegt. Zum Deaktivieren leerst du das jeweilige Feld und speicherst erneut.
- **NZB-Abruf:** NZBPort lädt Treffer der Indexer selbst und übergibt die NZB-Datei an SABnzbd. Der Indexer-Key wird nicht an SABnzbd gesendet.
- **Grenzen der Anbieter:** Ein direkter angemeldeter Test bei NinjaCentral lieferte einen passenden Treffer und eine gültige NZB-Datei. Ein angemeldeter NewzBay-Test endete mit HTTP 429; ein Live-Download ist daher nicht bestätigt. Die öffentlichen Capabilities von DrunkenSlug bestätigten die Titelsuche, eine angemeldete Live-Suche wurde jedoch nicht bestätigt. Für API-Zugriff auf NZBFinder ist eine Premium-Mitgliedschaft erforderlich; ein kostenloses Konto kann HTTP 401 mit API-Fehler 102 liefern. Verfügbarkeit und Bedingungen der Anbieter können sich ändern. HTML-Ausweichsuchen können ausfallen, wenn ein Anbieter Seiten ändert oder automatisierte Zugriffe sperrt. NZBPort umgeht keine Zugangssperren oder CAPTCHAs.

## Downloads, Menüleiste und Mitteilungen

- **Details zur Warteschlange:** Unter **Downloads** siehst du Titel, Fortschritt, Status und Kategorie pro Auftrag. Die Übersicht zeigt auch Gesamtgeschwindigkeit, Restgröße und geschätzte Restzeit.
- **Downloads steuern:** Pausiere einzelne Aufträge oder die ganze SABnzbd-Warteschlange und setze sie wieder fort.
- **Verlauf:** Die App zeigt die letzten zehn Einträge mit ihrem Status.
- **Status aktualisieren:** Aktualisiere die Downloadübersicht auf Wunsch manuell. Solange die Übersicht offen ist oder Mitteilungen aktiv sind, wartet NZBPort nach jedem Abruf zwei Sekunden bis zur nächsten Abfrage.
- **Kurzstatus in der Menüleiste:** Beim Öffnen des NZBPort-Menüs fragt die App die Anzahl der Aufträge und die Geschwindigkeit ab. Das Menü zeigt auch, wenn die Warteschlange leer oder pausiert, die Verbindung nicht eingerichtet oder der Status nicht verfügbar ist.
- **macOS-Mitteilungen:** Auf Wunsch meldet die App abgeschlossene und fehlgeschlagene Downloads. Bereits vorhandene Verlaufseinträge bleiben beim ersten Abruf außen vor. Ein Auftrag, der noch entpackt wird, gilt nicht als abgeschlossen.
- **SABnzbd im Browser öffnen:** Öffne den eingerichteten Server, ohne dass der API-Key in der Browseradresse steht.

## Sprache, Darstellung und Autostart

- **Sprache:** Wähle im App-Menü, Menüleistensymbol oder Zahnradmenü zwischen System, Deutsch und English. System folgt der ersten unterstützten macOS-Sprache und verwendet sonst Englisch. Eine manuelle Auswahl wird gespeichert und gilt sofort, auch für Menüs und app-eigene Fehlermeldungen.
- **Farbthemen:** Wähle Standard, Coffee, Elfenbein oder Minze. Die Themen passen sich an den hellen oder dunklen Modus an.
- **Darstellung und Hintergrund:** Wähle unabhängig vom Farbthema zwischen System, Hell und Dunkel. Der Fensterhintergrund kann systemgesteuert, transparent oder deckend sein.
- **Native macOS-Darstellung:** NZBPort verwendet Liquid-Glass-Bedienelemente. Das mit Icon Composer erstellte App-Symbol unterstützt die Systemdarstellungen.
- **Verbindungseinstellungen und Fensterhöhe:** Getrennte Gruppen ordnen die SABnzbd-Verbindung und die optionalen Suchdienst-Keys. Das Fenster wächst oder schrumpft passend zum Inhalt, soweit es die verfügbare Bildschirmhöhe zulässt. Reicht der Platz nicht aus, kannst du scrollen. Eine von Hand eingestellte Größe bleibt bis zum nächsten Öffnen erhalten.
- **Autostart:** Aktiviere oder deaktiviere den Start bei der Anmeldung im App-Menü, im Menüleistensymbol oder im Zahnradmenü. Wenn macOS eine Freigabe verlangt, wähle **In macOS erlauben …**. Beim Anmeldestart bleibt NZBPort in der Menüleiste. Beim manuellen Start öffnet sich das Fenster. Wenn SABnzbd noch startet, wiederholt NZBPort den Kategorienabruf bis zu dreimal mit 2, 5 und 10 Sekunden Wartezeit. Dauerhafte Fehler und abgelehnte Zugangsdaten werden weiterhin angezeigt. Der manuelle Start bleibt unverändert.

## Updates, Projektlinks und Quellcode

- **Nach Updates suchen:** Prüfe auf GitHub, ob es eine neuere Version gibt, auf Wunsch auch Testversionen. NZBPort öffnet die Release-Seite und lädt oder installiert Updates nicht automatisch.
- **Über NZBPort:** Öffne das GitHub-Projekt oder die [Portfolio-Seite](https://schrotty74.github.io/Portfolio/) im Standardbrowser.
- **Aus dem Quellcode bauen:** NZBPort ist in Swift geschrieben und nutzt Apple-Systemframeworks. Externe Pakete sind nicht nötig. Siehe [Build-Anleitung](../README.de.md#bauen) und [Datenschutz und Suchdienste](../README.de.md#datenschutz-und-suchdienste).

## Vom Link zum Download

1. Der Browser übergibt einen `nzblnk:`-Link an die registrierte macOS-App. Zuvor kann der Browser eine Bestätigung verlangen.
2. NZBPort liest Suchkennung (`h`), Titel (`t`), optionales Passwort (`p`) und wiederholte Gruppenfelder (`g`). Prozentkodierter Text wird unterstützt; abgekürzte `a.b.`-Gruppen werden für NZBIndex ausgeschrieben.
3. Die App ruft die aktuellen SABnzbd-Kategorien ab und berücksichtigt deine lokal ausgeblendeten Kategorien. Über das Suchfeld kannst du die Kategoriebuttons nach Namen filtern.
4. Mit der Kategorieauswahl beginnt die Suche bei NZBIndex, NZBKing und BinSearch. Bleibt sie erfolglos, sucht die App bei eingerichteten Anbietern in dieser Reihenfolge nach dem Releasetitel: Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug und NZBFinder. Für jeden ist ein eigener gespeicherter API-Key nötig.
5. NZBPort übergibt die öffentliche Downloadadresse oder die von einem Indexer geladene NZB-Datei zusammen mit Titel, Kategorie und optionalem Archivpasswort an SABnzbd. SABnzbd lädt die Usenet-Artikel.
6. Nach einer bestätigten Übergabe schließt sich das Fenster oder der nächste wartende Link erscheint. Bei einem Fehler bleibt die Meldung sichtbar. Läuft eine Übergabe in ein Timeout, prüfe vor einem neuen Versuch die SABnzbd-Warteschlange, um doppelte Aufträge zu vermeiden.

Mehrere unterschiedliche Trefferkennungen lehnt der NZBIndex-Provider ab; anschließend geht die Ausweichsuche weiter. Die HTML-Provider verwenden den ersten unterstützten Treffer ihrer Antwort. Suchtreffer garantieren weder Inhalt noch Verfügbarkeit. NZBPort verwaltet keine Usenet-Zugänge.
