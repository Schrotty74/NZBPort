# Nächste Schritte – NZBPort

Stand: 25. November 2026. Testversion 0.2.7, Build 11, ergänzt die Downloadordner-Überwachung und die Sicherung der App-Einstellungen. Diese Liste ist keine automatische Beauftragung zusätzlicher Arbeit.

## Noch nicht gesondert bestätigte Bedienungsfälle

- Die lokale macOS-27-Oberfläche im Alltag bestätigen: endgültige Federanimation des eigenen Zahnradbuttons und Darstellung mit aktivierter Systemeinstellung „Ränder anzeigen“. Knopfzustände wurden im Hintergrund gerendert, native Menüinhalte und lokale Favoritenreihenfolge automatisiert geprüft. Keine sichtbare Bedienung oder Änderung der Systemeinstellungen allein für weitere Prüfungen ausführen. Das Kategorie-Suchfeld wurde inzwischen tatsächlich aufgenommen: leichte Änderung der Glasreflexe, keine deutlich sichtbare Federbewegung. Der Aktualisieren-Button neben „Kategorie wählen“ verwendet lokal denselben Stil wie das Zahnrad; seine dargestellten Zustände wurden im Hintergrund geprüft. Der weitere Refresh-Button auf „Deine Kategorien“ wurde anschließend ebenfalls ergänzt und in der neu gestarteten App aufgenommen: Kreis, Vergrößerung sowie Druck- und Rückbewegung sind dort sichtbar. Das unveränderte Verhalten unter macOS 26 ist noch nicht gesondert bestätigt.

- Videothek nach der lokalen Ergänzung mit einem berechtigten Konto prüfen. Der Nutzer hat derzeit kein Premium und möchte den Anbieter zunächst in der Liste haben. Die öffentliche API bestätigt die Titelsuche; eine angemeldete Suche und ein NZB-Abruf sind nicht geprüft. Laut Anbieter werden Premium und die Freigabe des verwendeten Tools benötigt.

- Die Live-Suche bei NZBFinder mit einem Konto prüfen, das API-Zugriff hat. Der frühere Live-Test lieferte HTTP 401 und API-Fehler 102. Der simulierte Such- und Abrufweg war erfolgreich.

- Direkte Live-Suche und NZB-Abruf bei DrunkenSlug funktionierten mit einer 40-stelligen ID und einer Weiterleitung beim selben Anbieter. Unter iOS verursachte iCloud Privat-Relay beim Nutzertest eine Cloudflare-Sperre auch beim direkten API-Link in Safari. Nach Deaktivierung war der API-Link erreichbar; Suchanfragen wurden wieder gezählt, auch mit User-Agent und Domainfreigabe des Hauptskripts. Ein erfolgreicher NZB-Abruf im iOS-Skript steht noch aus. Keine experimentellen User-Agent- oder Domainänderungen übernehmen; bei erneuter Sperre Privat-Relay als mögliche Ursache prüfen. Details in PROJECT_CONTEXT.md.

- Das Anlegen und Löschen im eigenen Kategorienbereich ist vom Nutzer als funktionierend bestätigt. Keine zusätzlichen Kategorien oder Löschungen nur für Tests ausführen. Die automatisierten Prüfungen verwenden ausschließlich synthetische Daten.

- In der Mac-App „NZB-Datei speichern …“ mit dem nativen Speicherdialog prüfen und die gespeicherte Datei bei Bedarf manuell in SABnzbd öffnen. Automatisierte Tests decken Dateiabruf, unveränderte Passwortmetadaten, fehlende SABnzbd-Konfiguration, Abbrechen und Fehler ab.

- NinjaCentral im aktuellen iPhone-Skript mit gespeichertem API-Key prüfen. Ein früherer direkter API-Test lieferte einen passenden Treffer und eine gültige NZB-Datei.

- Neue Gruppierung der Verbindungseinstellungen in SABnzbd und optionale Suchdienste im normalen Betrieb bestätigen. Der Nutzer hat die vorherige Korrektur der Fensterhöhe als funktionierend bestätigt.
- Liste wartender Eingänge, Kategorieanzeige und Kurzstatus im geöffneten Menü im normalen Betrieb prüfen.
- Die Zwei-Sekunden-Aktualisierung im normalen Betrieb bestätigen. Der bisherige Kategorien-Klappbereich in den Verbindungen ist durch die eigene Kategorienansicht ersetzt.
- Echte Abschluss-/Fehlermeldungen mit erteilter macOS-Benachrichtigungsfreigabe beobachten, einschließlich geschlossenem Fenster bei weiterlaufender Menüleisten-App. Keine zusätzlichen Downloads oder künstlichen Fehler allein dafür auslösen.
- Plattformkompatibilität auf macOS 26 und 27 getrennt bestätigen, bevor beide als praktisch getestet bezeichnet werden.

## Planung: NZBPort als eigenständiger Usenet-Downloadmanager

Der Vorschlag ist dokumentiert, aber noch nicht zur Umsetzung beauftragt. Heute prüft NZBPort die NZB-Datei und übergibt den Auftrag an SABnzbd. Für den Direktdownload braucht NZBPort einen eigenen Download-Kern. Menüleiste, NZBlnk-Suche, Dateiimport, Downloadübersicht und Mitteilungen können als Grundlage bleiben.

### Was der Download-Kern übernehmen müsste

- **Usenet-Verbindung:** Server und Zugangsdaten des Usenet-Anbieters in NZBPort hinterlegen und über NNTP mit TLS verbinden. Der Usenet-Anbieter bleibt nötig. SABnzbd und sein API-Key entfallen im direkten Modus. Grundlagen: [NNTP (RFC 3977)](https://www.rfc-editor.org/info/rfc3977/) und [TLS für NNTP (RFC 4642)](https://www.rfc-editor.org/info/rfc4642/).
- **Dateien herunterladen:** Die in einer NZB-Datei aufgeführten Teile parallel abrufen, dekodieren und auf der Festplatte zusammensetzen. Nach einem Verbindungsabbruch bereits vollständig geladene Teile erkennen und nur die fehlenden erneut abrufen.
- **Warteschlange speichern:** Aufträge über das Beenden der App und einen Neustart hinweg erhalten. NZBPort verwaltet Pause, Fortsetzen, Priorität, Fortschritt und Verlauf selbst. Kategorien können auf lokale Zielordner verweisen.
- **Prüfen, reparieren und entpacken:** Dateien prüfen und fehlende oder beschädigte Teile mit PAR2 reparieren, soweit genügend Reparaturdaten vorhanden sind. Archive automatisch entpacken und ein vorhandenes Passwort verwenden. Vor einer Eigenentwicklung vorhandene Werkzeuge für Reparatur und Entpacken prüfen. Als Referenzen dienen die [Nachbearbeitung in SABnzbd](https://sabnzbd.org/wiki/extra/job-options) und das [PAR2-Werkzeug par2cmdline](https://github.com/parchive/par2cmdline). Die Auswahl von Abhängigkeiten ist offen.

### Empfohlene Reihenfolge

1. **Direktdownload für einen Anbieter:** Eine lokale `.nzb`-Datei öffnen, herunterladen und nach einem Neustart der App fortsetzen. Ziel ist ein zuverlässiger Download auf die Festplatte.
2. **Ersatz für den Alltag:** Wenn der Download zuverlässig läuft, NZBlnk als weiteren Eingang ergänzen, Dateien mit PAR2 prüfen und reparieren, Archive automatisch entpacken und Zielordner nach Kategorie wählen.

Den Direktdownload zunächst zusätzlich zur SABnzbd-Übergabe anbieten. So lassen sich dieselben NZB-Dateien mit beiden Wegen vergleichen. Ein Umstieg ist sinnvoll, wenn Fortsetzen, Reparatur und Entpacken bei typischen Downloads zuverlässig funktionieren.

### Download auf dem Mac, Bedienung am Handy

NZBPort lädt ausschließlich auf dem Mac herunter und verarbeitet die Dateien dort. Ein separater Dienst auf einem NAS oder Server ist nicht vorgesehen. Bei geschlossenem Fenster kann der Download weiterlaufen, solange NZBPort in der Menüleiste aktiv und der Mac wach ist. Im Ruhezustand oder bei ausgeschaltetem Mac sind Download und Fernsteuerung nicht verfügbar.

Für die Bedienung am Handy soll NZBPort eine Weboberfläche bereitstellen. Im selben Heimnetz öffnest du sie im Handy-Browser über die lokale IP-Adresse des Macs, ähnlich wie bisher die SABnzbd-Oberfläche. Dort sollst du die Warteschlange und den Fortschritt sehen sowie Downloads starten, pausieren und fortsetzen können. Die Weboberfläche steuert dieselbe Warteschlange wie die Mac-App. Das Handy lädt selbst keine Usenet-Daten herunter.

- Favoriten-Ziehen ist im korrigierten lokalen Stand mit einem echten Maus-Drag und gespeicherter Reihenfolge bestätigt. Die Testfavoriten wurden entfernt. Keine erneuten Versuche ohne konkreten neuen Fehler; Details im letzten Nachtrag von PROJECT_CONTEXT.md.

- Die native harte Scrollkante ist unter macOS 27 lokal konfiguriert und gebaut. Eine tatsächliche Scrollaufnahme liegt noch nicht vor. Keine Vordergrundaktivierung; nur eine störungsfreie Hintergrundprüfung verwenden.
