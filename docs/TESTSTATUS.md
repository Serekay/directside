# Teststand vom 24. Oktober 2026

Entwicklungsstand, keine Release-Freigabe.

## Windows

- Rust-Kern lokal kompiliert. Vier Tests prüfen das Drei-App-Limit samt Erneuerung bestehender Apps, die Erkennung anhand korrekter Bundle-IDs den lokalen Anisette-Callback samt Neusynchronisierung sowie die ausdrückliche Bestätigung vor Löschvorgängen. Zwei zusätzliche Vendor-Tests prüfen Callback-Payloads, passenden und unpassenden Schlüssel-/Zertifikatsimport sowie die Erkennung vorhandener privater Schlüssel.
- 41 Python-Tests bestanden: IPA-Auswahl, Voreinstellungen ohne Passwort, lokale Anmeldung, Komponentenprüfung, Hashprüfung, integrierte Bestätigungen, automatisches Gerätescannen, getrennte Gerätezustände, Icon-Cache und gespeicherte Sprachwahl. QML-Regressionstests prüfen Eingabeerhalt, Anmeldeklick und App-ID-Kontingente. Weitere Tests prüfen den abgelehnten Token, DPAPI-Schutz samt Manipulationserkennung und die Beschränkung der Provisionierung auf Apple-HTTPS-Endpunkte.
- Die echte gepackte EXE wurde mit --smoke-test gestartet: Qt, QML, Fenster-Icon, eigene Titelleiste, Signierkern und tatsächliche lokale Anisette-Erzeugung erfolgreich. Bericht: build/smoke-test.json.
- Die frühere native Windows-CoreADI bestand OTP-Tests, scheiterte beim echten Xcode-Token aber weiterhin mit −80046, auch nach Anpassung des Clientprofils. Die alte Sitzung wurde mit Fehler 1100 zurückgewiesen. Diese Tests bestätigten keine erfolgreiche Anmeldung.
- Neuer Windows-Provider: Apples Mac-CoreADI aus iTunes 12.8.3 unter lokalem Unicorn. Tatsächliche Provisionierung bei Apple mit geprüfter TLS-Verbindung, lokale OTP-Erzeugung und Wiederverwendung des DPAPI-geschützten Zustands erfolgreich. Derselbe Weg wurde in der fertig gepackten EXE einschließlich Rust-Kern und besitzergeschützter Windows-Pipe erfolgreich geprüft. Keine Apple-ID bei diesen Tests verwendet. Der Besitzer hat die erfolgreiche Apple-ID-Anmeldung in der neuen gepackten Windows-App am 24. Oktober ausdrücklich bestätigt.
- Ein zusätzlicher Rust-Vendor-Test prüft den OTP-Wechsel am echten 30-Sekunden-Fenster. Der Windows-Build verwendet einen selbst gebauten PyInstaller-Starter gemäß dokumentierter `--no-cfg`-Kompatibilitätsoption; keine Windows-Richtlinie wurde verändert. Der frühere Paketabsturz mit Unicorn tritt im aktuellen Starttest nicht mehr auf.
- Am angeschlossenen Gerät wurden 191 Benutzer-Apps gelesen. LocalDevVPN wurde erkannt; LiveContainer war nicht vorhanden. Drei angefragte echte App-Icons wurden erfolgreich von SpringBoard Services gelesen.
- Offizielle LiveContainer-Standalone-IPA 3.8.0 heruntergeladen; SHA-256 und Haupt-Bundle-ID geprüft. Keine Installation oder Zertifikatsübertragung auf dem Gerät vorgenommen.
- Apple-USB-Dienst war auf diesem PC bereits installiert und gestartet. Deshalb wurde keine Neuinstallation ausgelöst. Download-/Prüf-/Startpfade wurden mit Testdaten geprüft; ein kompletter Installerlauf auf einem unvorbereiteten PC steht aus.
- Oberfläche auf Mindestgröße 960 × 680 in Deutsch und Englisch geprüft: kurze VPN-Karte, farbige Status-Badges, Hilfe aus dem ⋯-Menü, Einstellungen und App-Kacheln ohne Haupt-Scrollbar.
- Überarbeitete Windows-Oberfläche mit synthetischen Daten außerhalb des Benutzerfensters gerendert: Status unten rechts, bündige Konto-/Geräteüberschriften, USB im Header und unterschiedliche Vektor-Icons. Keine Anmeldung mit Test-Zugangsdaten ausgelöst.

Der frühere QtCore-DLL-Fehler kam von einer fremden ICU-DLL im Build-PATH. Der lokale Paketbau isoliert diesen Pfad und schließt die fremde DLL aus.

## GitHub-Updates

- Release-Erkennung am echten privaten Repository mit der bestehenden GitHub-Anmeldung auch aus der fertig gepackten EXE geprüft: Zugriff erfolgreich, noch keine freigegebene Version vorhanden. Bericht: build/release-probe.json. Keine Release-Erstellung oder Uploads.
- Vierzehn neue Tests decken Release-/Privatzugriff, Versionsvergleich, Weiterleitungen ohne Tokenweitergabe an das CDN, SHA-256-Prüfung, beschädigte Downloads, fremde IPA-Bundle-IDs, DPAPI-Tokenablage, EXE-Austausch samt Sicherung und Wiederherstellung, gesperrte Dateien sowie UI-Zustand und aufgeschobenen Neustart während einer Anmeldung ab. Zusätzlich geprüft: direkter Download mit anschließender Installation, Warten auf USB-Abfragen, unveränderte eigene IPA-Auswahl und Abbruch bei gewechseltem Zielgerät.
- Neue Windows-EXE unter build/github-updates/DirectSide.exe lokal gebaut; erneuter echter Paketstarttest mit Qt, QML, Fenster-Icon, Rust-Kern und lokaler Apple-Authentifizierung bestanden. Die bislang geöffnete dist/DirectSide.exe wurde nicht beendet oder ersetzt.
- Oberfläche mit simuliertem Release auf Mindestgröße in Deutsch und Englisch gerendert. Ein Geometrietest prüft die komplette IPA-Zeile innerhalb der Karte bei vorhandenem und fehlendem VPN. Der QR-Bereich passt sich an die Kartenhöhe an; kein Überlagern des Kartenrands. Ein Install-DirectSide-Button, ein Windows-Update-Button im Header und IPA-Version am App-Kopf. Echte Release-Downloads und vollständige Versions-Upgrades bleiben bis zur ersten freigegebenen Version ungetestet.

## iPhone und LiveContainer

Aktuelle IPA: Quellstand `53be0e7`, Version 0.1.0, Build 2. Privater manueller Build:
https://github.com/Serekay/directside/actions/runs/40094299353 . Die IPA wurde nach
`dist/DirectSide.ipa` übernommen und auf Bundle-ID, Buildnummer, eingebetteten
Mac-Runtime-Hash, fehlende Android-Bibliotheken, IPA-Dokumenttyp, VPN-URL-Schema
und Lizenzdateien geprüft.

Die lokale iOS-Anmeldung verwendet jetzt dieselbe echte Mac-CoreADI wie Windows,
mit x86-64-Gastemulation unter TCI und ausschließlich les-/schreibbarem
Interpreter-Speicher. Rust-Mac-Adapter, Swift-Provisionierung, iOS-C-Callbacks samt
Neusynchronisierung und Signierkern wurden gemeinsam mit Xcode kompiliert. Die
frühere ARM64/AnisetteKit-Abhängigkeit ist entfernt.

Auf dem Buildrechner bestanden tatsächliche Apple-Provisionierung, Export des
modernen Provisionierungszustands, Laden in einen neu erzeugten Interpreter und
wiederholte OTP-Erzeugung. Keine Apple-ID oder Anmeldedaten wurden dabei verwendet
oder in Actions gespeichert. Der beim Portieren gefundene Verlust des Zustands
nach einem virtuellen Prozessneustart wurde durch Ausschließen der veralteten
adi.pb bei Sitzungsneustarts behoben. Beide erfolgreichen neuen Builds führten
diese Probe mit dem Software-Interpreter aus, nicht mit JIT.

Der Geräte-Installationsversuch des Besitzers scheiterte noch vor der eigentlichen
Installation mit Apple-Fehler 7460 (Zertifikatlimit). Deshalb ist eine erfolgreiche
Anmeldung oder Selbst-Erneuerung auf dem echten iPhone weiterhin nicht bestätigt.
Das iPhone wurde per USB erkannt. Die neue Windows-EXE und die neue IPA enthalten
nun ausdrücklich bestätigte App-Entfernung sowie Zertifikatverwaltung. Es wurde
kein Zertifikat automatisch widerrufen und keine Benutzer-App für einen Test
gelöscht. Der nächste Hardwaretest erfolgt über diese Oberfläche.

Direkter IPA-Import über Dateien und „Öffnen in“, Vorschau der Haupt-App und
Weitergabe an den vorhandenen lokalen Signier-/Installationspfad sind kompiliert.
Der native Inspector akzeptierte die echte DirectSide-IPA und lehnte ein
Testarchiv mit zwei Haupt-Apps ab. Der vollständige Import mit anschließender
Geräteinstallation bleibt noch am iPhone zu prüfen.

Die VPN-Leiste ist auf allen Tabs und in den modalen Ansichten eingebaut. Sie
prüft im Vordergrund alle fünf Sekunden die tatsächliche TCP-Erreichbarkeit des
lokalen Remote-Pairing-Ports. Das ist ein Erreichbarkeitstest, keine Abfrage des
privaten Prozesszustands von LocalDevVPN und kein Ersatz für die kryptografische
Pairingprüfung. Das offizielle Schema `localdevvpn://enable?scheme=directside`
öffnet/aktiviert die VPN-App und führt zu DirectSide zurück. Diese Übergabe und
die Statusänderung beim Abschalten sind noch am Gerät zu prüfen.

Die optionale LiveContainer-Installation und lokale Zertifikatsübergabe bleiben
gebaut, jedoch noch nicht am Gerät getestet. Ein eingebettetes LiveContainer-
Laufzeitsystem ist nicht umgesetzt.

## Vor einer Freigabe offen

- Frische lokale Windows-Anmeldung vom Besitzer bestätigt; weitere Varianten der Zwei-Faktor-Bestätigung separat prüfen.
- Zertifikatlimit über die neue Oberfläche lösen; Signierung und Erstinstallation der eigenen IPA samt Remote-Pairing.
- Lokale iOS-Authentifizierung am echten Gerät einschließlich 2FA und Wiederherstellung der Sitzung prüfen.
- App-Installation aus Quelle und direkter IPA, Update mit Datenerhalt und Selbsterneuerung über LocalDevVPN.
- Bestätigtes Entfernen fremd installierter Apps und Widerrufen eines ausgewählten Zertifikats auf PC und iPhone.
- VPN-App-Übergabe, Rückkehr und sichtbarer Status bei ausgeschaltetem Tunnel.
- Wiederherstellung einer abgelaufenen Xcode-Sitzung aus dem neuen, im Schlüsselbund gespeicherten Refresh-Kontext. Dieser neue Kontext enthält kein Passwort; bestehende alte Sitzungen benötigen einmalig eine neue Anmeldung.
- Gleichzeitiger Hardwaretest mit mehreren Geräten; bisherige Trennungsprüfungen verwenden simulierte Ereignisse.
- LiveContainer-Installation, Zertifikatseinrichtung und Start einer Gast-App.

Windows wird ausschließlich lokal gebaut. iPhone-Actions sind nur manuell auslösbar. Das GitHub-Repository bleibt privat; es gibt keine öffentliche Veröffentlichung und keinen Release.
