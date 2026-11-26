# NZBPort-Userscript fürs iPhone

[English](README.md)

Öffne [NZBPort.user.js](https://raw.githubusercontent.com/Schrotty74/NZBPort/main/Userscripts/NZBPort.user.js) in Safari und installiere es mit der Userscripts-Erweiterung. Das Skript läuft unabhängig von der Mac-App. Eine JSON-Sicherung aus dem vorherigen Skript kannst du in den Skript-Einstellungen unter **Import / Export** öffnen und anschließend speichern.

## Funktionen

- Tippe auf einen NZBlnk, um nach dem passenden Release zu suchen. Ist die Kategorieauswahl eingestellt, öffnet sich nach einem Treffer das Menü. Sobald du eine Kategorie auswählst, sendet das Skript die NZB an SABnzbd.
- Wähle auf NewzBay **Download → An SABnzbd senden**. Das Skript nutzt deine NewzBay-Anmeldung in Safari. Bei aktivierter Erkennung sendet es direkt, wenn eine passende SABnzbd-Kategorie verfügbar ist. Sonst öffnet es das Kategorienmenü.
- Im Bereich **Indexer** kannst du die Suchreihenfolge ändern und Dienste einzeln deaktivieren. Im Bereich **SABnzbd** legst du eigene Titelregeln und Zielkategorien fest. Seit 0.1.3 erkennt das Skript auch das eigenständige Wort „Complete“ als Serienmerkmal.
- Mit **NZB-Datei speichern** kannst du die geprüfte NZB lokal ablegen.
- In den Einstellungen kannst du API-Keys für Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder und Videothek hinterlegen. Videothek setzt API-Zugang und die Freigabe des Tools voraus. Die exportierte Einstellungsdatei enthält deine API-Keys. Bewahre sie privat auf.
