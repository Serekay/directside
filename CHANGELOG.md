# Änderungen

## Unreleased

- Aktuelle freigegebene DirectSide-IPA direkt aus GitHub laden; eigene IPA-Dateien bleiben auswählbar.
- Windows-Updateprüfung beim Start, alle sechs Stunden und manuell; Update-Schaltfläche, Download mit GitHub-SHA-256-Prüfung und Neustart mit gesicherter vorheriger EXE.
- Privater GitHub-Zugang in den Einstellungen, DPAPI-geschützt; vorhandene Projekt-GitHub-Anmeldung auf dem Entwicklungs-PC wiederverwendbar. Keine Veröffentlichungen ausgelöst.
- Besitzer bestätigt erfolgreiche Apple-ID-Anmeldung mit dem neuen lokalen Windows-Mac-Provider.

- Windows-Anisette durch eingebettete Mac-iTunes-CoreADI ersetzt: lokale Unicorn-Emulation, verschlüsselter Zustand, geprüfte TLS-Verbindung und interne Windows-Pipe statt Fremdserver oder zusätzlicher Installation. Tatsächliche lokale Provisionierung und OTP-Erzeugung auf Windows geprüft; Apple-ID-Login vom Besitzer bestätigt.
- Getrennte akd-/Xcode-Identitäten für Anmeldung und Developer-API, frische OTP-Daten pro 30-Sekunden-Fenster und korrigierte Fortschrittsmeldung vor abgeschlossener Anmeldung.

- Apple-ID-Eingabe bleibt bei automatischen Geräteabfragen erhalten. Anmeldeklicks während einer Abfrage werden anschließend ausgeführt; Passwort wird nur bei angenommener Anmeldung aus dem Eingabefeld entfernt.
- Abgelaufene Sitzungen klar gekennzeichnet; kein irreführendes „Bereit“ im abgemeldeten Zustand. App-ID-Verbrauch aus Apples tatsächlichem Registrierungskontingent, getrennt von installierten Apps pro Gerät.
- USB-Badge neben der Version, Hilfe-Fragezeichen, größere unterschiedliche Vektor-Icons für Aktualisierung und App-Übersicht; ausgerichtete Überschriften, kompakter Installationsbereich und Statusleiste unten rechts.

- Aktivität vollständig kopierbar: Textauswahl, Strg+C und Kopieren-Button; Fehlerdetails über die Fußleiste erreichbar.
- Windows-Clientprofil an den lokalen iTunes-Anisette-Provider angepasst; Der nachfolgende Mac-CoreADI-Provider behebt den beobachteten Tokenfehler beim Account des Besitzers.
- Lokale iOS-Anmeldung über AnisetteKit-TCI implementiert; ARM64-IPA gebaut und tatsächliche Provisionierung mit wiederholter OTP-Erzeugung auf macOS geprüft. Hardwareprüfung von Anmeldung und Selbsterneuerung ausstehend.
- Vorhandene Windows-Signieridentität mit Schlüssel-/Zertifikatsprüfung auf iOS importierbar; integrierte SMS-Bestätigung auf iOS.

- Automatische USB-Erkennung, App-Belegung und VPN-Prüfung pro Gerät. Benutzer-Apps als Kacheln mit echten Geräte-Icons und Seitenwechsel ohne Scrollbar.
- Kurze LocalDevVPN-Karte mit lokalem App-Store-QR-Code; rote, gelbe und grüne Status-Badges.
- Hilfe im ⋯-Menü und gespeicherte Sprachwahl Englisch/Deutsch; Standard Englisch.
- Optionale LiveContainer-Standalone-Installation mit Hashprüfung und lokaler Zertifikatsübertragung. iOS-Übergabe gebaut; Hardwaretest ausstehend.

- Windows-Anisette lokal über CoreADI im eigenen Prozess; kein automatischer Fremdserver-Fallback und keine Serveradresse in den Einstellungen.
- Komponentenprüfung mit Fehlend-/Gestoppt-/Installiert-Badges und integrierter Einrichtung der Apple-USB-Unterstützung; Apple-Download mit SHA-256-Prüfung und regulärer Windows-Administratorbestätigung.
- Lokale iOS-Authentifizierung ausdrücklich noch nicht implementiert; Selbsterneuerung und LiveContainer-Integration nicht als funktionsgeprüft freigegeben.

- Qt-Quick-Oberfläche im iLoader-Stil: Karten, Status-Badges, Icon-Einstellungen und eigene Titelleiste ohne Scrollbar in der Hauptansicht.
- Integrierte Bestätigungen und lokal gespeicherte Apple-ID samt Schlüsselbund-Sitzung.
- Inkompatible ICU-DLL aus dem Paket entfernt; isolierter Build und Starttest der fertigen EXE für Qt, QML, Icon und Signierkern.
- Windows ausschließlich lokal gebaut; iPhone-Actions nur manuell. Alte Oberflächen und Paketvarianten entfernt, technische Dokumentation unter `docs/` geordnet.

## 0.1.0 — Entwicklung

- Eigenes DirectSide-Branding und App-Icon.
- Native Magazin-Oberfläche mit App-Katalog, Quellen und Detailseiten.
- QR-/URL-Quellenimport, Screenshots, Versionsverlauf und Update-Erkennung.
- Gemeinsamer Signierkern für Windows und iPhone.
- Windows-Erstinstallation mit automatischer Übertragung von Remote-Pairing und Original-IPA.
- Einzel- und Sammelerneuerung sowie eigene Selbsterneuerung.
- Private Build-Artefakte für iPhone und Windows.

Noch nicht als stabile Version freigegeben. Geräteprüfung steht aus.
