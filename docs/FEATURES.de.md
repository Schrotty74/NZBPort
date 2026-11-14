# Funktionen von NZBPort

[Zurück zur README](../README.de.md) · [English](FEATURES.md)

## Links, Dateien und wartende Eingänge

Öffne einen NZBlnk-Link aus Safari, füge ihn über **NZBlnk aus Zwischenablage** ein oder ziehe ihn ins Fenster. NZBPort prüft beim Start und beim Aktivieren die macOS-Zuordnung. Ist die App bereits als Standard eingetragen, zeigt der Button **Als Link-App eingerichtet**.

NZB-Dateien kannst du über die Dateiauswahl, über **Öffnen mit** im Finder oder per Drag-and-drop öffnen. Pro Datei sind bis zu 16 MiB erlaubt. Für wartende NZB-Dateien und die aktuelle Datei gilt zusammen ein Limit von 64 MiB. NZBPort bearbeitet die Eingänge nacheinander. Unter **Wartende Links und Dateien** siehst du, was als Nächstes dran ist, und kannst einzelne Einträge vor der Übergabe entfernen.

## Kategorien und Übergabe

NZBPort lädt die SABnzbd-Kategorien beim Start, beim Öffnen eines Auftrags und auf Wunsch auch manuell. Der Abruf beim Start läuft im Hintergrund. Fehler bei der Verbindung oder der Übergabe zeigt die App an.

In den **Verbindungseinstellungen** kannst du **Deine Kategorien** auf- und zuklappen, Kategorien ausblenden oder wieder einblenden und Favoriten anheften und sortieren. Diese Änderungen gelten nur in NZBPort. Neue Kategorien von SABnzbd erscheinen automatisch. Wähle vor der Übergabe eine Kategorie und bei Bedarf eine andere Priorität oder **Pausiert hinzufügen**.

Bei erkannten Wiederholungen innerhalb von zehn Minuten bittet NZBPort um Bestätigung. Das gilt auch nach einer unklaren Übertragung. Für diese Prüfung bleiben nur Hashes und Zeitstempel im Arbeitsspeicher. Wenn unklar ist, ob SABnzbd einen Auftrag angenommen hat, prüfe vor einem neuen Versuch die Warteschlange.

## Downloads, Menüleiste und Mitteilungen

Unter **Downloads** siehst du Fortschritt, Status und Kategorie der wartenden und laufenden Aufträge. Dazu kommen die Gesamtgeschwindigkeit, Restgröße und Restzeit sowie die letzten Aufträge. Du kannst die Ansicht aktualisieren und einzelne Aufträge oder die ganze Warteschlange pausieren und fortsetzen.

Das Menü von NZBPort zeigt die Anzahl der Aufträge und, falls verfügbar, die Downloadgeschwindigkeit. Es meldet auch eine leere oder pausierte Warteschlange und zeigt an, wenn der Status nicht verfügbar ist. Beim Öffnen fragt NZBPort den Status ab. Über **SABnzbd im Browser öffnen** erreichst du den Server, ohne dass der API-Key in der Browseradresse steht.

Optionale macOS-Mitteilungen melden abgeschlossene und fehlgeschlagene Downloads. Beim ersten Abruf bleibt der bereits vorhandene Verlauf außen vor. Ein Auftrag, der noch entpackt wird, gilt nicht als abgeschlossen. Solange die Downloadübersicht offen ist oder Mitteilungen aktiv sind, wartet NZBPort nach jedem Statusabruf zwei Sekunden bis zur nächsten Abfrage.

## Updates

Über **Nach Updates suchen** prüfst du, ob es auf GitHub eine neuere Version gibt. Auf Wunsch bezieht NZBPort Testversionen ein. Die App öffnet die Release-Seite; sie lädt und installiert Updates nicht automatisch.

## Sprache, Darstellung und Autostart

Die Oberfläche unterstützt Deutsch und Englisch. Im App-Menü, im Menüleistensymbol und im Zahnradmenü wählst du unter **Sprache** zwischen **System, Deutsch und English**. Standardmäßig verwendet die App die erste unterstützte Sprache aus deinen macOS-Einstellungen. Ist keine dabei, verwendet sie Englisch. Eine manuelle Auswahl wird lokal gespeichert und gilt sofort, auch für Menüs und app-eigene Fehlermeldungen.

Im App-Menü und im Zahnradmenü wählst du zwischen den Farbthemen **Standard, Coffee, Elfenbein und Minze**. Davon unabhängig lassen sich System, Hell und Dunkel sowie ein systemgesteuerter, transparenter oder deckender Fensterhintergrund wählen. Die Farbthemen passen sich dem hellen und dunklen Modus an; die Auswahl wird lokal gespeichert. Die Bedienelemente nutzen natives Liquid Glass. Das Icon-Composer-Dokument unterstützt die Systemdarstellungen des App-Icons.

Das Hauptfenster wächst bei Bedarf bis zum sichtbaren Bildschirmrand. Reicht der Platz nicht aus, kannst du scrollen. Eine von Hand eingestellte Größe bleibt bis zum nächsten Öffnen erhalten.

Unter **Autostart → Beim Anmelden starten** im App-Menü, im Menüleistensymbol oder im Zahnradmenü schaltest du den Start bei der macOS-Anmeldung ein oder aus. Die Einstellung wird erst durch deine Auswahl geändert. Verlangt macOS eine Freigabe, führt **In macOS erlauben …** zu den Anmeldeobjekten in den Systemeinstellungen. Beim Anmeldestart bleibt NZBPort in der Menüleiste. Beim manuellen Start öffnet sich das Fenster.

**Über NZBPort** führt zum GitHub-Projekt und zur [Portfolio-Homepage](https://schrotty74.github.io/Portfolio/). Die Links öffnen sich erst nach deiner Auswahl im Standardbrowser.

## Vom Link zum Download

1. Der Browser übergibt einen `nzblnk:`-Link an die registrierte macOS-App. Zuvor kann der Browser eine Bestätigung verlangen.
2. NZBPort liest Suchkennung (`h`), Titel (`t`), optionales Passwort (`p`) und wiederholte Gruppenfelder (`g`). Prozentkodierter Text wird unterstützt; abgekürzte `a.b.`-Gruppen werden für NZBIndex ausgeschrieben.
3. Die App ruft die aktuellen SABnzbd-Kategorien ab und berücksichtigt deine lokal ausgeblendeten Kategorien. Über das Suchfeld kannst du die Kategoriebuttons nach Namen filtern.
4. Mit der Kategorieauswahl beginnt die Suche. Zuerst wird die öffentliche JSON-API von NZBIndex ohne zusätzlichen Such-API-Key verwendet. Schlägt die Suche fehl, folgen NZBKing und BinSearch mit ihren öffentlichen Suchantworten.
5. NZBPort übergibt Downloadadresse, Titel, gewählte Kategorie und optionales Archivpasswort an SABnzbd. Den Download übernimmt SABnzbd; NZBPort lädt selbst keine Usenet-Artikel.
6. Nach einer bestätigten Übergabe schließt sich das Fenster oder der nächste wartende Link erscheint. Bei einem Fehler bleibt die Meldung sichtbar. Läuft eine Übergabe in ein Timeout, prüfe vor einem neuen Versuch die SABnzbd-Warteschlange, um doppelte Aufträge zu vermeiden.

Mehrere unterschiedliche Trefferkennungen lehnt der NZBIndex-Provider ab; anschließend geht die Ausweichsuche weiter. Die HTML-Provider verwenden den ersten unterstützten Treffer ihrer Antwort. Suchtreffer garantieren weder Inhalt noch Verfügbarkeit. Die App legt keine SABnzbd-Kategorien an, löscht keine Kategorien und verwaltet keine Usenet-Zugänge.
