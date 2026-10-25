# Änderungen

## 0.1.1 (16) - 2026-10-25

- 0.1.1 (16): Version und Buildnummer in Windows und iPhone sichtbar, Windows-Dateieigenschaften versioniert, vier iPhone-Ansichten in der vereinfachten README.
- iPhone: VPN-Status in Einstellungen, Installationshinweis bei getrennter Verbindung, Tastaturabschluss außerhalb von Textfeldern und verständliche Berechtigungen.
- Entwicklermodus in Installation, Hilfe, iPhone-Einstellungen und README vor dem ersten App-Start erklärt.
- Sideload-Apps mit Geräte-Icons; reguläre App-Store-Apps aus der Verwaltung entfernt. Löschen in Meine Apps per Wischen oder langem Drücken mit Bestätigung.
- iPhone-Selbstupdater für freigegebene Releases mit Größen-/SHA256-/Versions-/App-ID-Prüfung und Übernahme der neuen Original-IPA. Updates nur bei betroffenen App-Zeilen.
- LiveContainer installiert mit vorbereitetem Zertifikat; Einrichtung abschließen startet die Zertifikatsübergabe. Später einrichten ersetzt den irreführenden Fertig-Button.
- Bezahlte Teams anhand tatsächlicher Profile behandelt; P12-/Profilimport ohne Apple-Anmeldung in beiden Apps einschließlich USB-Übernahme ans iPhone.
- Quellen und Apps klar getrennt; vereinfachter Dialog zum Hinzufügen mit QR-Symbolknopf.
- Windows lokal und iPhone-Build auf macOS geprüft. Native Update-Prüfung steht aus. Details in [Teststand](docs/TESTSTATUS.md).

## 0.1.0 - 2026-10-24

- First release: Windows app and iPhone IPA (build 5).
- Local Apple authentication, automatic USB setup and device management.
- App sources over HTTP/HTTPS, IPA import, signature management and optional LiveContainer integration.
- Saved English/German preferences and Windows release updates.
- Source refresh cancellation fixes, swipe-to-remove sources and signature expiry badges.
- Hardware-confirmed sign-in and setup transfer. Self-renewal and the LiveContainer JIT-less diagnostic still require device verification.

## Development history (before 0.1.0)

The notes below record earlier implementation stages; current verification is documented in [Test status](docs/TESTSTATUS.md).


- iOS auf dieselbe Mac-CoreADI wie Windows umgestellt: lokaler x86-64-TCI-Interpreter ohne JIT, Schlüsselbundzustand und Neusynchronisierung. Echte Apple-Provisionierung samt neuem Interpreter und wiederholter OTP-Erzeugung im Build geprüft; iPhone-Anmeldung und Selbsterneuerung noch am Gerät zu bestätigen.
- App-Entfernung auf PC und iPhone für alle gelesenen Benutzer-Apps, unabhängig vom ursprünglichen Installer; bestätigte Zertifikatverwaltung mit Team-Zuordnung und Erkennung vorhandener Signierschlüssel. Kein automatischer Widerruf bei Fehler 7460.
- iPhone importiert IPA-Dateien aus Dateien/„Öffnen in“, prüft die Haupt-App und verwendet den lokalen Signierpfad. Dauerhafte VPN-Anzeige, regelmäßiger Erreichbarkeitstest und offizieller LocalDevVPN-Link mit Rückkehr.
- Xcode-Token kann nach neuer Anmeldung aus einem passwortfreien, im OS-Schlüsselbund gespeicherten Refresh-Kontext erneuert werden. Hardwaretest der Token-Erneuerung ausstehend.


- Ein Button „Install DirectSide“ lädt die aktuelle freigegebene IPA und installiert sie auf dem gewählten Gerät. Eigene IPAs bleiben getrennt auswählbar und installierbar. IPA-Versions-Badge am App-Kopf; Windows-Update-Schaltfläche nur im Header.
- VPN-Karte passt den QR-Bereich an die verfügbare Höhe an; eigene IPA-Zeile bleibt vollständig innerhalb der Karte. Text: „Auf dem ausgewählten Gerät installieren“.
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
