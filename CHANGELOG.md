# Änderungen

## Unreleased

- Aktivität vollständig kopierbar: Textauswahl, Strg+C und Kopieren-Button; Fehlerdetails über die Fußleiste erreichbar.
- Windows-Clientprofil an den lokalen iTunes-Anisette-Provider angepasst; Behebung von Apples Tokenfehler −80046 noch am Account zu prüfen.
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
