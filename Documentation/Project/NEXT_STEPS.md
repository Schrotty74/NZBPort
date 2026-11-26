# Nächste Schritte – NZBPort

Stand: 26. November 2026. Testversion 0.2.8, Build 12, ergänzt die automatische Kategoriezuordnung, die einstellbare Suchreihenfolge und die gemeinsamen Untermenüs. Diese Liste ist keine automatische Beauftragung zusätzlicher Arbeit.

## Noch nicht gesondert bestätigte Bedienungsfälle

- Die automatische Kategoriezuordnung mit eigenen SABnzbd-Kategorien im normalen Betrieb bestätigen. Der automatische Versand und die manuelle Auswahl wurden mit simulierten Antworten geprüft. Beim separaten iPhone-Userscript 0.1.3 steht die Prüfung auf dem Gerät aus.

- Die Scrollkante von Build 11 unter macOS 27 bei passendem Anlass im Hintergrund prüfen. Kopf- und Fußleiste verwenden `safeAreaBar`. Eine Sichtprüfung dieser Fassung steht aus. Die Darstellung mit „Ränder anzeigen“ ist ebenfalls noch separat zu bestätigen. Die bestätigte Ziehgeste und den geprüften Aktualisieren-Button auf „Deine Kategorien“ nur bei einem konkreten neuen Fehler erneut prüfen.
- Beim Import der Einstellungen ist noch offen, ob macOS das Anmeldeobjekt wie vorgesehen wiederherstellt. Der Nutzer hat Export, Zurücksetzen und Import bereits ausprobiert.
- Videothek hat die Mac-App und das iPhone-Userscript freigegeben. Eine erfolgreiche Live-Suche mit anschließendem NZB-Abruf steht noch aus. Dafür ist ein Konto mit API-Zugang nötig.

- Die Live-Suche bei NZBFinder mit einem Konto prüfen, das API-Zugriff hat. Der frühere Live-Test lieferte HTTP 401 und API-Fehler 102. Der simulierte Such- und Abrufweg war erfolgreich.

- Direkte Live-Suche und NZB-Abruf bei DrunkenSlug funktionierten mit einer 40-stelligen ID und einer Weiterleitung beim selben Anbieter. Unter iOS verursachte iCloud Privat-Relay beim Nutzertest eine Cloudflare-Sperre auch beim direkten API-Link in Safari. Nach Deaktivierung war der API-Link erreichbar; Suchanfragen wurden wieder gezählt, auch mit User-Agent und Domainfreigabe des Hauptskripts. Ein erfolgreicher NZB-Abruf im iOS-Skript steht noch aus. Keine experimentellen User-Agent- oder Domainänderungen übernehmen; bei erneuter Sperre Privat-Relay als mögliche Ursache prüfen. Details in PROJECT_CONTEXT.md.

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
