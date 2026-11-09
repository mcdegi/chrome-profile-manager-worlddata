# Chrome Profile Manager – öffentliche Weltdaten

Der bisherige Datensammler läuft unabhängig vom Desktop-Programm auf einem öffentlichen
GitHub-Standard-Runner. Es werden keine kostenpflichtigen Runner, Actions-Artefakte,
Caches oder externen Cloud-Dienste verwendet. Der Manager-Quellcode bleibt privat.

Die Erfassung für **de258** ist stündlich zur Minute 37 geplant. GitHub kann geplante
Läufe verzögern oder auslassen. Der letzte vollständige Stand bleibt dann erhalten.
Eine separate persistente Reservierung verhindert schnelle Wiederholungsabrufe nach
fehlgeschlagenen oder abgebrochenen Jobs. Neue Daten werden erst nach Prüfung und
erfolgreichem Upload über `feeds/de258.json` freigegeben.

## Windows Server als Sammler

Das [Serverpaket 0.2.14](https://github.com/mcdegi/chrome-profile-manager-worlddata/releases/tag/server-v0.2.14)
ist fuer Windows x64, PowerShell 5.1 und .NET Framework 4.8+ vorbereitet.
[Einrichtung](server/README.txt): Paket nach C:\DSHub-Weltdaten entpacken,
Initialize ausfuehren und nur ServerPublicKey.xml fuer den separaten
verschluesselten Datenschluesseltransfer weitergeben. Keine privaten Schluessel,
GitHub-Tokens oder Windows-Kennwoerter veroeffentlichen.

Die Uebergabe erfolgt erst nach einem erfolgreichen Server-Probelauf mit
-ClaimServer. Bis dahin bleibt der bisherige GitHub-Zeitplan aktiv. Danach
verhindert feeds/de258-host.json weitere Spielserver-Abfragen durch GitHub.
Die Windows-Aufgabe prueft alle fuenf Minuten; neue Originaldaten werden
hoechstens einmal je voller Stunde geladen. Sie laeuft auch ohne RDP-Sitzung.
Ein dauerhaft erreichbarer vorhandener Server ist erforderlich. Es werden keine
zusaetzlichen kostenpflichtigen Cloud-Dienste eingerichtet.

Der Collector 0.2.14 verarbeitet nicht atomare angezeigte Dorfzahlen konservativ
anhand der tatsaechlichen Dorfbesitzer. Unsichere Neustarts bleiben offen;
Signaturen, Punkte-0-Filter und das bestehende Datenformat bleiben erhalten.

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
