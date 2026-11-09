DSHub-Weltdaten fuer Windows Server - 0.2.14

Voraussetzung: Windows x64 mit Desktop-/Framework-Komponenten, .NET Framework
4.8 oder neuer und Windows PowerShell 5.1. Fuer die Einrichtung Administratorrechte.
Das Paket enthaelt keine Zugangsdaten, privaten Schluessel oder Browserprofile.

1. ZIP-Pruefsumme mit der veroeffentlichten SHA256 vergleichen. ZIP in den
   Dateieigenschaften zulassen bzw. mit Unblock-File entsperren. Alle Dateien
   direkt nach C:\DSHub-Weltdaten entpacken. Vorhandene Konfigurationen nicht
   blind ueberschreiben. Unterordner und Skripte bleiben dauerhaft dort.

2. Als derselbe Windows-Benutzer, unter dem spaeter die Aufgabe laufen soll:

   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File C:\DSHub-Weltdaten\Setup-Server.ps1 -Mode Initialize

   Nur den angezeigten OEFFENTLICHEN ServerPublicKey an Codex senden. Die Datei
   .secrets\transport-key.dpapi bleibt auf dem Server. Codex verschluesselt den
   bestehenden Datenschluessel fuer genau diesen Server. Die Rueckdatei wird
   separat uebertragen; sie ist kein Bestandteil dieses ZIP.

3. Auf GitHub einen fine-grained Personal Access Token erstellen:
   https://github.com/settings/personal-access-tokens/new
   Besitzer mcdegi; nur Repository chrome-profile-manager-worlddata;
   Repository-Berechtigung Contents: Read and write. Kein Zugriff auf andere
   Repositories oder Workflow-/Kontoverwaltung erforderlich. Ablaufdatum merken
   und Token rechtzeitig ueber denselben Einrichtungsmodus ersetzen.

   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File C:\DSHub-Weltdaten\Setup-Server.ps1 -Mode GitHub

   Token nur in der verdeckten Server-Eingabe eingeben, nicht im Chat oder in
   Skriptdateien. Der Schreibzugriff wird an einer harmlosen Setup-Metadatei
   geprueft. Token und private Schluessel werden mit DPAPI CurrentUser abgelegt.

4. Die fuer diesen Server verschluesselte Transferdatei als
   C:\DSHub-Weltdaten\data-key.cpmkey ablegen. Dann:

   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File C:\DSHub-Weltdaten\Setup-Server.ps1 -Mode ImportKey -KeyFile C:\DSHub-Weltdaten\data-key.cpmkey

   Ein alter DPAPI-Schluessel vom anderen PC ist nicht direkt verwendbar. Die
   Transferdatei ist an den oeffentlichen Schluessel aus Schritt 2 gebunden.

5. Manueller Probelauf und Uebergabe:

   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File C:\DSHub-Weltdaten\Run-Server.ps1 -ClaimServer

   Erst eine Meldung 'Erfolgreich veroeffentlicht' und status.json mit Success
   true belegen den vollstaendigen Probelauf. 'Noch kein Abruf faellig' ist kein
   neuer Datenstand. Das bestehende stuendliche Quellenlimit bleibt wirksam.
   Bei Fehlern logs\<UTC-Datum>.log pruefen; vorhandene Daten nicht loeschen.

   Nach erfolgreicher Veroeffentlichung setzt -ClaimServer die Besitzmarkierung
   feeds/de258-host.json. Der angepasste GitHub-Workflow macht dann keine eigenen
   Spielserver-Abfragen mehr. Der Betreiber deaktiviert danach den GitHub-
   Zeitplan. Der Manager liest dieselben signierten Downloads wie bisher.

6. Aufgabe erst nach erfolgreichem Probelauf aktivieren:

   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File C:\DSHub-Weltdaten\Register-ServerTask.ps1 -Enable

   Das Windows-Kennwort dieses Benutzers wird verdeckt abgefragt. Die Aufgabe
   verwendet Kennwortanmeldung und laeuft auch ohne RDP-Sitzung; nicht als SYSTEM
   einrichten, da die privaten Dateien an den Einrichtungsbenutzer gebunden sind.
   Die Aufgabe prueft alle fuenf Minuten auf faellige Arbeit. Oeffentliche
   Spielserver-Dateien werden hoechstens einmal je voller Stunde abgerufen.
   Ausgefallene Starts werden nachgeholt, keine parallelen Instanzen gestartet.
   Zeitlimit 20 Minuten; Netzwerk-/Uploadfehler lassen den letzten Stand erhalten.

7. Status und Wartung:

   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File C:\DSHub-Weltdaten\Setup-Server.ps1 -Mode Status
   Get-ScheduledTaskInfo -TaskName ChromeProfileManager-Weltdaten-de258

   Ein neuer Datenstand muss auf GitHub als de258-... erscheinen. Der Manager
   prueft beim Start und alle fuenf Minuten; GitHub-CDN-Caches koennen zusaetzlich
   verzoegern. Nach Schliessen von RDP einen spaeteren Stundenstand kontrollieren.

Rohdaten und lokale Outboxes bleiben 48 Stunden erhalten. Der neueste gueltige
signierte Stand, Neustartliste und Vergleichszustand bleiben dauerhaft erhalten.
Logs rotieren nach 14 Tagen. Uploads werden erst nach erneutem Download und
Hashvergleich freigegeben; unterbrochene Draft-Uploads werden wiederaufgenommen.
Spielerlisten und Dorfdateien sind nicht atomar: Dorfbesitzer sind massgeblich,
verspaetete angezeigte Dorfzahlen blockieren nicht die ganze Welt. Punkte-0-Filter,
Adelungsnachweise, unbekannte Besitzer und unsichere Neustarts bleiben abgesichert.
Ein ausgeschalteter Server kann fehlende historische Stundenstaende nicht exakt
nachtraeglich erzeugen. Der Dienst benoetigt einen dauerhaft erreichbaren Server.

RemoteSigned wird nur fuer den jeweiligen PowerShell-Prozess gewaehlt. Es wird
keine globale Ausfuehrungsrichtlinie geaendert; erzwungene Gruppenrichtlinien
bleiben wirksam. Fuer den Sammler werden keine eingehenden Ports benoetigt.
