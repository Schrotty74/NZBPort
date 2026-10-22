# Nächste Schritte – NZBPort

Stand: 22. Oktober 2026. Lokal 0.2, Build 4; veröffentlicht ist die Testversion 0.1.1. Veröffentlichung von 0.2 ist ausdrücklich beauftragt. Diese Liste ist keine automatische Beauftragung zusätzlicher Arbeit.

## Vor einer ausdrücklich beauftragten Veröffentlichung

- Englische und deutsche README auf den freigegebenen Zielstand abgleichen: Zwei-Sekunden-Abfrage, klappbare Kategorien und neue Downloadfunktionen. Veraltete Aussagen zur fehlenden Warteschlangensteuerung korrigieren; Funktionen als Feature-Liste aufführen.
- Bestehende lokale Änderungen prüfen und nur freigegebene Quellen, Ressourcen, Tests und bereinigte Begleitdateien übernehmen. Projektkontext zum veröffentlichten Stand passend nachführen.
- Öffentliche Bundle-ID verwenden und sicherstellen, dass keine lokalen Einstellungen, privaten Serveradressen, Keys oder persönlichen Links in Quellen oder Paketen enthalten sind.
- Bei entsprechendem Release-Auftrag DMG mit Applications-Verknüpfung, ZIP und Prüfsummen erzeugen und prüfen; erst danach auf ausdrückliche Freigabe beziehungsweise im Umfang des ausdrücklichen Veröffentlichungsauftrags hochladen.

## Noch nicht gesondert bestätigte Bedienungsfälle

- Den neuen Klappbereich und die Zwei-Sekunden-Aktualisierung im normalen Betrieb bestätigen.
- Echte Abschluss-/Fehlermeldungen mit erteilter macOS-Benachrichtigungsfreigabe beobachten, einschließlich geschlossenem Fenster bei weiterlaufender Menüleisten-App. Keine zusätzlichen Downloads oder künstlichen Fehler allein dafür auslösen.
- Plattformkompatibilität auf macOS 26 und 27 getrennt bestätigen, bevor beide als praktisch getestet bezeichnet werden.

Ein vollständiger eigener Usenet-Downloadmanager ist nur eine besprochene Idee. Keine Implementierung und keine neue Abhängigkeit ohne weiteren Auftrag.
