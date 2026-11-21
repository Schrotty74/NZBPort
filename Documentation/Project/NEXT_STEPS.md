# Nächste Schritte – NZBPort

Stand: 21. November 2026. Testversion 0.2.4, Build 8, ergänzt Treasure Maps und NewzBay. Diese Liste ist keine automatische Beauftragung zusätzlicher Arbeit.

## Noch nicht gesondert bestätigte Bedienungsfälle

- NewzBay mit eigenem API-Key in den Verbindungseinstellungen prüfen. Der direkte Suchtest lieferte HTTP 429 und keine Trefferliste. Der Nutzer hat die drei ursprünglich fehlenden Releases bereits mit der integrierten Treasure-Maps-Suche gefunden.
- Automatische Fensterhöhe in den Verbindungseinstellungen, Liste wartender Eingänge, Kategorieanzeige und Kurzstatus im geöffneten Menü im normalen Betrieb prüfen.
- Den neuen Klappbereich und die Zwei-Sekunden-Aktualisierung im normalen Betrieb bestätigen.
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
