# Teststand vom 24. Oktober 2026

Entwicklungsstand, keine Release-Freigabe.

## Windows

- Rust-Kern lokal kompiliert. Drei Tests prüfen das Drei-App-Limit samt Erneuerung bestehender Apps, die Erkennung anhand korrekter Bundle-IDs und den lokalen Anisette-Callback. Zwei zusätzliche Vendor-Tests prüfen Callback-Payloads sowie passenden und unpassenden Schlüssel-/Zertifikatsimport.
- 35 Python-Tests bestanden: IPA-Auswahl, Voreinstellungen ohne Passwort, lokale Anmeldung, Komponentenprüfung, Hashprüfung, integrierte Bestätigungen, automatisches Gerätescannen, getrennte Gerätezustände, Icon-Cache und gespeicherte Sprachwahl. QML-Regressionstests prüfen Eingabeerhalt, Anmeldeklick und App-ID-Kontingente. Weitere Tests prüfen den abgelehnten Token, DPAPI-Schutz samt Manipulationserkennung und die Beschränkung der Provisionierung auf Apple-HTTPS-Endpunkte.
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
- Elf neue Tests decken Release-/Privatzugriff, Versionsvergleich, Weiterleitungen ohne Tokenweitergabe an das CDN, SHA-256-Prüfung, beschädigte Downloads, fremde IPA-Bundle-IDs, DPAPI-Tokenablage, EXE-Austausch samt Sicherung und Wiederherstellung, gesperrte Dateien sowie UI-Zustand und aufgeschobenen Neustart während einer Anmeldung ab.
- Neue Windows-EXE unter build/github-updates/DirectSide.exe lokal gebaut; erneuter echter Paketstarttest mit Qt, QML, Fenster-Icon, Rust-Kern und lokaler Apple-Authentifizierung bestanden. Die bislang geöffnete dist/DirectSide.exe wurde nicht beendet oder ersetzt.
- Oberfläche mit simuliertem Release auf Mindestgröße gerendert. Echte Release-Downloads und vollständige Versions-Upgrades bleiben bis zur ersten freigegebenen Version ungetestet.

## iPhone und LiveContainer

Die aktuelle unsignierte IPA für Commit 1d9b5af wurde mit Xcode erstellt und auf Archivstruktur, ARM64-Programm und eingebettete Anisette-Runtime geprüft. Privater Build: https://github.com/Serekay/directside/actions/runs/40083954661 .

Lokale iOS-Authentifizierung ist über Swift-AnisetteKit-TCI und den Rust-C-Callback implementiert. Auf dem macOS-Buildrechner bestanden echte Apple-Provisionierung und wiederholte OTP-Erzeugung ohne Apple-ID. Das bestätigt den lokalen Anisette-Weg, jedoch keine Apple-ID-Anmeldung oder Selbsterneuerung auf dem iPhone. Kein Fremdserver-Fallback. Der neue lokale Windows-Mac-Provider ist kein iOS-Provider. Die aktuelle IPA enthält weiterhin den zuvor gebauten ARM64-AnisetteKit-Weg; Änderungen am gemeinsamen Quellcode seit Commit 1d9b5af wurden noch nicht erneut für iOS gebaut.

Die optionale Windows-Einrichtung für LiveContainer und der Quellcode für die lokale Zertifikatsübergabe sind vorhanden. Standalone-Installation, Übertragung, iOS-Schlüsselbundimport, Übergabe an LiveContainer und dessen JIT-less-Test sind noch gemeinsam am Gerät zu prüfen. Ein integriertes LiveContainer-Laufzeitsystem ist nicht umgesetzt.

## Vor einer Freigabe offen

- Frische lokale Windows-Anmeldung vom Besitzer bestätigt; weitere Varianten der Zwei-Faktor-Bestätigung separat prüfen.
- Signierung und Erstinstallation der eigenen IPA samt Remote-Pairing.
- Lokale iOS-Authentifizierung am echten Gerät einschließlich 2FA und Wiederherstellung der Sitzung prüfen.
- App-Installation, Update mit Datenerhalt und Selbsterneuerung über LocalDevVPN.
- Gleichzeitiger Hardwaretest mit mehreren Geräten; bisherige Trennungsprüfungen verwenden simulierte Ereignisse.
- LiveContainer-Installation, Zertifikatseinrichtung und Start einer Gast-App.

Windows wird ausschließlich lokal gebaut. iPhone-Actions sind nur manuell auslösbar. Das GitHub-Repository bleibt privat; es gibt keine öffentliche Veröffentlichung und keinen Release.
