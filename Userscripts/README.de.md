# nzb-load für iOS-Userscripts

[English](README.md)

Das ursprüngliche [nzb-load-Skript](https://github.com/LordBex/nzb-load) stammt von LordBex. Wir pflegen [unsere Fassung](nzb-load.user.js) als Ergänzung zu NZBPort. Das Skript läuft unabhängig von der Mac-App.

Version `v2.3.7`

## Änderungen gegenüber dem Original

- Nach den bisherigen öffentlichen Suchdiensten kann das Skript sechs weitere Indexer abfragen. Dazu gehören Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder und Videothek. Jeder Dienst hat ein eigenes API-Key-Feld, das anfangs leer ist. Videothek setzt API-Zugang und die Freigabe des Tools voraus.
- „NZB-Datei speichern“ steht im Kategorienmenü und nach einer fehlgeschlagenen Übergabe zur Verfügung. Das Speichern ist auch möglich, wenn SABnzbd noch nicht eingerichtet oder nicht erreichbar ist. Das Skript prüft die Antwort vor dem Speichern und übernimmt ein vorhandenes Archivpasswort in den Dateinamen.
- Bei der direkten Übergabe an SABnzbd verwendet das Skript wieder die eingestellte Standardkategorie.
- Die Unterstützung für NZBGet und die wirkungslose Einstellung für Erfolgsmeldungen wurden entfernt. Weiterhin unterstützte Einstellungen übernimmt das Skript aus älteren Versionen.

## Kennung für Videothek

Das Skript setzt für die Suche und den Abruf von NZB-Dateien bei Videothek diesen User-Agent:

```text
NZBPort/nzb-load/2.3.7 (NZB link search; iOS Userscripts)
```

Das Skript übergibt die Kennung in beiden Fällen an `indexerRequest`. Der Userscript-Manager verschickt die Anfragen. Eine Aufnahme des tatsächlichen Netzwerkverkehrs auf dem iPhone steht noch aus.

Der Mac-Client verwendet eine eigene feste Kennung. Sie steht im [Quellcode des Newznab-Clients](../Sources/RelayCore/NewznabClient.swift).

```text
NZBPort/0.2.5 (+https://github.com/Schrotty74/NZBPort)
```

API-Keys gehören weder ins Repository noch in Downloadlinks, GitHub-Issues oder Support-Nachrichten.
