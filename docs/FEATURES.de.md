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
- **Automatische Kategoriezuordnung:** Unter **Kategorien** ordnest du Serien, Spielen, Filmen und sonstigen Titeln SABnzbd-Kategorien zu. Die erste passende eigene Titelregel mit verfügbarem Ziel hat Vorrang. Sonst prüft NZBPort die Kennungen im Releasetitel. Das eigenständige Wort „Complete“ zählt auch ohne Episodennummer als Serienmerkmal. Bei NZBlnk-Links dient der Titel als Grundlage, bei NZB-Dateien der Dateiname.
- **Automatisch erkennen und senden:** Aktiviere den Modus unter **Kategorien**. Ist eine passende Kategorie sichtbar und verfügbar, sendet NZBPort direkt. Ohne passende Zuordnung öffnet sich die Kategorieauswahl. Bei ausgeschaltetem automatischem Versand markiert NZBPort die passende Kategorie als Empfehlung.
- **Kategorie anlegen:** Auf der eigenen Seite **Kategorien** kannst du eine Kategorie in SABnzbd anlegen.
- **Kategorie löschen:** Das Löschen einer vorhandenen Kategorie in SABnzbd musst du bestätigen. Die Standardkategorie ist geschützt. Dabei ändert sich die Kategorienkonfiguration; wartende Aufträge und bereits geladene Dateien bleiben erhalten.
- **Lokale Kategorieeinstellungen:** Auf der Seite **Kategorien** kannst du Kategorien ausblenden oder wieder einblenden und Favoriten anheften und sortieren. Diese Änderungen gelten nur in NZBPort. Neue Kategorien von SABnzbd erscheinen automatisch.
- **Priorität:** Wähle vor der Übergabe Niedrig, Normal, Hoch oder Sofort. Mit **Pausiert hinzufügen** legst du einen Auftrag an, ohne ihn zu starten.
- **Titel und Archivpasswort:** NZBPort übergibt den Titel und ein im NZBlnk-Link enthaltenes Archivpasswort zusammen mit der gewählten Kategorie an SABnzbd.
- **Rückmeldung zur Übergabe:** Sobald SABnzbd einen automatisch gesendeten Auftrag annimmt, zeigt NZBPort die Zielkategorie drei Sekunden lang an. Die App zeigt den nächsten Eingang oder schließt das Fenster. Fehler bei der Verbindung oder Übergabe bleiben sichtbar.
- **Duplikatwarnung:** Bei erkannten Wiederholungen innerhalb von zehn Minuten bittet NZBPort um Bestätigung, auch nach einer unklaren Übertragung. Für die Prüfung bleiben nur Hashes und Zeitstempel im Arbeitsspeicher. Wenn unklar ist, ob SABnzbd den Auftrag angenommen hat, prüfe vor einem neuen Versuch die Warteschlange.

## Suchdienste

- **Suchreihenfolge:** Unter **Einstellungen → Verbindung → Suchdienste** änderst du die Reihenfolge mit Pfeilen und schaltest Dienste einzeln ein oder aus. Die Reihenfolge gilt beim Senden von Links und beim Speichern ihrer NZB-Dateien. NZBPort überspringt deaktivierte Dienste und Dienste ohne erforderlichen API-Key.
- **Suchergebnisse:** Der erste gültige Treffer beendet die Suche. Bei Fehlern, unpassenden Titeln oder mehrdeutigen API-Treffern sucht NZBPort beim nächsten Dienst weiter.

| Standardposition | Anbieter | Such-API-Key |
| --- | --- | --- |
| 1 | NZBIndex | Nein, öffentliche API |
| 2 | NZBKing | Nein |
| 3 | BinSearch | Nein |
| 4 | Treasure Maps | Optional, separat gespeichert |
| 5 | NewzBay | Optional, separat gespeichert |
| 6 | NinjaCentral | Optional, separat gespeichert |
| 7 | DrunkenSlug | Optional, separat gespeichert |
| 8 | NZBFinder | Optional, separat gespeichert; API-Zugriff erfordert Premium-Mitgliedschaft |
| 9 | Videothek | Optional, separat gespeichert; API-Berechtigung und zugelassenes Tool erforderlich |

- **Anfragen an Anbieter:** Ein eingerichteter Indexer erhält den Releasetitel und seinen eigenen API-Key. Beim Speichern legt NZBPort die Keys lokal und unverschlüsselt ab. Wenn du einen Anbieter deaktivierst, bleibt sein Key gespeichert.
- **NZB-Abruf:** NZBPort lädt Treffer der Indexer selbst und übergibt die NZB-Datei an SABnzbd. Der Indexer-Key wird nicht an SABnzbd gesendet.
- **Grenzen der Anbieter:** Ein direkter angemeldeter Test bei NinjaCentral lieferte einen passenden Treffer und eine gültige NZB-Datei. Bei NewzBay folgt die App für den NZB-Abruf einer HTTPS-Weiterleitung zum Download-Endpunkt desselben Anbieters. Bei DrunkenSlug waren eine Live-Suche und der NZB-Abruf mit einer 40-stelligen Hex-ID erfolgreich. Für API-Zugriff auf NZBFinder ist eine Premium-Mitgliedschaft erforderlich; ein kostenloses Konto kann HTTP 401 mit API-Fehler 102 liefern. Verfügbarkeit und Bedingungen der Anbieter können sich ändern. HTML-Ausweichsuchen können ausfallen, wenn ein Anbieter Seiten ändert oder automatisierte Zugriffe sperrt. NZBPort umgeht keine Zugangssperren oder CAPTCHAs.

## Downloadordner und Sicherung

- Unter **Einstellungen → Downloadordner** wählst du einen Ordner aus. Für neu eingetroffene, fertige NZB-Dateien gelten dieselben Kategorieeinstellungen wie für manuell geöffnete Dateien. Nach erfolgreicher Übergabe an SABnzbd wandert die Originaldatei in den Papierkorb. Bei Fehlern oder Abbruch bleibt sie im Ordner.
- Unter **Einstellungen → Sicherung** kannst du Mac-Einstellungen als JSON exportieren und wiederherstellen. Die Datei enthält auch API-Keys, Favoriten, Titelregeln und die Indexer-Auswahl. Vor dem Wiederherstellen siehst du die gespeicherte SABnzbd-Adresse, den Downloadordner und gegebenenfalls einen Hinweis zum automatischen Versand. Die Datei enthält API-Keys im Klartext. Bei fehlender macOS-Ordnerfreigabe wählst du den überwachten Ordner erneut aus. An derselben Stelle kannst du NZBPort auf die Standardwerte zurücksetzen.

## Downloads, Menüleiste und Mitteilungen

- **Details zur Warteschlange:** Unter **Downloads** siehst du Titel, Fortschritt, Status und Kategorie pro Auftrag. Die Übersicht zeigt auch Gesamtgeschwindigkeit, Restgröße und geschätzte Restzeit.
- **Downloads steuern:** Pausiere einzelne Aufträge oder die ganze SABnzbd-Warteschlange und setze sie wieder fort.
- **Verlauf:** Die App zeigt die letzten zehn Einträge mit ihrem Status.
- **Status aktualisieren:** Aktualisiere die Downloadübersicht auf Wunsch manuell. Solange die Übersicht offen ist oder Mitteilungen aktiv sind, wartet NZBPort nach jedem Abruf zwei Sekunden bis zur nächsten Abfrage.
- **Kurzstatus in der Menüleiste:** Beim Öffnen des NZBPort-Menüs fragt die App die Anzahl der Aufträge und die Geschwindigkeit ab. Das Menü zeigt auch, wenn die Warteschlange leer oder pausiert, die Verbindung nicht eingerichtet oder der Status nicht verfügbar ist.
- **Gemeinsame Untermenüs:** Das Menüleistensymbol und das Zahnrad verwenden dieselben Menüs für **Einstellungen** und **Über NZBPort**. Warteschlangenstatus, Öffnen und Beenden sind direkt am Menüleistensymbol erreichbar.
- **macOS-Mitteilungen:** Auf Wunsch meldet die App abgeschlossene und fehlgeschlagene Downloads. Bereits vorhandene Verlaufseinträge bleiben beim ersten Abruf außen vor. Ein Auftrag, der noch entpackt wird, gilt nicht als abgeschlossen.
- **SABnzbd im Browser öffnen:** Öffne den eingerichteten Server, ohne dass der API-Key in der Browseradresse steht.

## Sprache, Darstellung und Autostart

- **Sprache:** Wähle im App-Menü, Menüleistensymbol oder Zahnradmenü zwischen System, Deutsch und English. System folgt der ersten unterstützten macOS-Sprache und verwendet sonst Englisch. Eine manuelle Auswahl wird gespeichert und gilt sofort, auch für Menüs und app-eigene Fehlermeldungen.
- **Farbthemen:** Wähle Standard, Coffee, Elfenbein oder Minze. Die Themen passen sich an den hellen oder dunklen Modus an.
- **Darstellung und Hintergrund:** Wähle unabhängig vom Farbthema zwischen System, Hell und Dunkel. Der Fensterhintergrund kann systemgesteuert, transparent oder deckend sein.
- **Native macOS-Darstellung:** NZBPort verwendet Liquid-Glass-Bedienelemente. Das mit Icon Composer erstellte App-Symbol unterstützt die Systemdarstellungen.
- **Verbindungsstatus:** **Verbindung prüfen** testet die eingetragene SABnzbd-Adresse mit dem aktuellen API-Key. Änderst du eines der Felder, wird das Prüfergebnis zurückgesetzt. Der Test speichert die Eingaben nicht.
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
4. Nach der manuellen oder automatischen Kategorieauswahl sucht NZBPort bei den aktivierten Anbietern in der eingestellten Reihenfolge. Öffentliche Suchdienste verwenden die Suchkennung, Indexer mit API-Key den Releasetitel.
5. NZBPort übergibt die öffentliche Downloadadresse oder die von einem Indexer geladene NZB-Datei zusammen mit Titel, Kategorie und optionalem Archivpasswort an SABnzbd. SABnzbd lädt die Usenet-Artikel.
6. Nach einer bestätigten Übergabe schließt sich das Fenster oder der nächste wartende Link erscheint. Bei einem Fehler bleibt die Meldung sichtbar. Läuft eine Übergabe in ein Timeout, prüfe vor einem neuen Versuch die SABnzbd-Warteschlange, um doppelte Aufträge zu vermeiden.

Mehrere unterschiedliche Trefferkennungen lehnt der NZBIndex-Provider ab; anschließend geht die Ausweichsuche weiter. Die HTML-Provider verwenden den ersten unterstützten Treffer ihrer Antwort. Suchtreffer garantieren weder Inhalt noch Verfügbarkeit. NZBPort verwaltet keine Usenet-Zugänge.

Videothek ist ab 0.2.6 verfügbar. Der Anbieter hat Mac-App und iOS-Userscript freigegeben. Der letzte Test mit API-Key lieferte Fehlercode 500. Eine erfolgreiche Suche und der NZB-Abruf stehen noch aus.
