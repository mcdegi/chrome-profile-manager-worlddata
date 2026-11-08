# Chrome Profile Manager – öffentliche Weltdaten

Dieser Datensammler läuft unabhängig vom Desktop-Programm auf einem öffentlichen
GitHub-Standard-Runner. Es werden keine kostenpflichtigen Runner, Actions-Artefakte,
Caches oder externen Cloud-Dienste verwendet. Der Manager-Quellcode bleibt privat.

Die Erfassung für **de258** ist stündlich zur Minute 37 geplant. GitHub kann geplante
Läufe verzögern oder auslassen. Der letzte vollständige Stand bleibt dann erhalten.
Eine separate persistente Reservierung verhindert schnelle Wiederholungsabrufe nach
fehlgeschlagenen oder abgebrochenen Jobs. Neue Daten werden erst nach Prüfung und
erfolgreichem Upload über `feeds/de258.json` freigegeben.

Der Manager prüft beim Start und alle fünf Minuten. GitHubs CDN kann den kleinen
Zeiger zusätzlich einige Minuten zwischenspeichern; neue Veröffentlichungen sind
deshalb nicht an jedem Standort sofort sichtbar.

- [Aktuelle Spieler-Neustartliste](https://github.com/mcdegi/chrome-profile-manager-worlddata/releases/latest/download/player-starts.csv)
- [Aktuelles vollständiges Datenpaket](https://github.com/mcdegi/chrome-profile-manager-worlddata/releases/latest/download/worlddata.zip)
- [Historische Stände](https://github.com/mcdegi/chrome-profile-manager-worlddata/releases)

CSV: `player_id,timestamp`, Komma, Unix-Sekunden UTC. Spieler mit 0 Punkten fehlen.
Neue Spieler erhalten ihren ersten Erfassungszeitpunkt. Bestätigte Neustarts ersetzen
die vorherige Zeit. Unentscheidbare Übergänge überschreiben keine bekannte Zeit.
Zeitstempel sind Beobachtungszeiten, keine sekundengenauen Spielaktionen.

Datensnapshots werden 48 Stunden aufbewahrt. Der letzte gültige Gesamtstand samt
Neustartliste und Vergleichszustand bleibt unabhängig davon erhalten. Große Dateien
liegen als Release-Downloads vor; Git enthält nur Workflow, Dokumentation und kleine
Metadaten. Der Collector ist eine fest gepinnte Windows-Binärdatei mit Prüfsumme und
verwendet dieselbe Erkennungslogik wie der Manager. Ein separater Datenschlüssel
signiert die Pakete; im Client liegt ausschließlich der öffentliche Prüfschlüssel.

Quellen: öffentliche Dateien unter `https://de258.die-staemme.de/map/` sowie die
öffentlichen Weltkonfigurationen. Keine DSHub-Tokens, Cookies, Browserprofile oder
persönlichen Manager-Einstellungen werden benötigt oder veröffentlicht.
