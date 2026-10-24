# Teststand vom 24. Oktober 2026

Entwicklungsstand, keine Release-Freigabe.

## Windows

- Rust-Kern lokal kompiliert. Drei Tests prüfen das Drei-App-Limit samt Erneuerung bestehender Apps, die Erkennung anhand korrekter Bundle-IDs und den lokalen Anisette-Callback. Zwei zusätzliche Vendor-Tests prüfen Callback-Payloads sowie passenden und unpassenden Schlüssel-/Zertifikatsimport.
- 21 Python-Tests bestanden: IPA-Auswahl, Voreinstellungen ohne Passwort, lokale Anmeldung, Komponentenprüfung, Hashprüfung, integrierte Bestätigungen, automatisches Gerätescannen, getrennte Gerätezustände, Icon-Cache und gespeicherte Sprachwahl mit Englisch als Standard. Neue QML-Regressionstests prüfen Eingabeerhalt während einer Geräteabfrage, anschließend ausgeführten Anmeldeklick und rote/gelbe/grüne App-ID-Kontingente anhand tatsächlicher Apple-Antwortfelder.
- Die echte gepackte EXE wurde mit --smoke-test gestartet: Qt, QML, Fenster-Icon, eigene Titelleiste, Signierkern und tatsächliche lokale Anisette-Erzeugung erfolgreich. Bericht: build/smoke-test.json.
- CoreADI erzeugt lokal Machine Data und OTP. Es wird kein Fremd-Anisette-Dienst verwendet. Die alte gespeicherte Developer-Sitzung wurde von Apple als abgelaufen zurückgewiesen (1100). Eine frische Anmeldung bestand die Passwortprüfung, scheiterte aber beim Xcode-App-Token mit Apple-Fehler −80046. Das Windows-/iTunes-Clientprofil wurde danach angepasst; eine erfolgreiche Anmeldung ist damit noch nicht bestätigt.
- Am angeschlossenen Gerät wurden 191 Benutzer-Apps gelesen. LocalDevVPN wurde erkannt; LiveContainer war nicht vorhanden. Drei angefragte echte App-Icons wurden erfolgreich von SpringBoard Services gelesen.
- Offizielle LiveContainer-Standalone-IPA 3.8.0 heruntergeladen; SHA-256 und Haupt-Bundle-ID geprüft. Keine Installation oder Zertifikatsübertragung auf dem Gerät vorgenommen.
- Apple-USB-Dienst war auf diesem PC bereits installiert und gestartet. Deshalb wurde keine Neuinstallation ausgelöst. Download-/Prüf-/Startpfade wurden mit Testdaten geprüft; ein kompletter Installerlauf auf einem unvorbereiteten PC steht aus.
- Oberfläche auf Mindestgröße 960 × 680 in Deutsch und Englisch geprüft: kurze VPN-Karte, farbige Status-Badges, Hilfe aus dem ⋯-Menü, Einstellungen und App-Kacheln ohne Haupt-Scrollbar.
- Überarbeitete Windows-Oberfläche mit synthetischen Daten außerhalb des Benutzerfensters gerendert: Status unten rechts, bündige Konto-/Geräteüberschriften, USB im Header und unterschiedliche Vektor-Icons. Keine Anmeldung mit Test-Zugangsdaten ausgelöst.

Der frühere QtCore-DLL-Fehler kam von einer fremden ICU-DLL im Build-PATH. Der lokale Paketbau isoliert diesen Pfad und schließt die fremde DLL aus.

## iPhone und LiveContainer

Die aktuelle unsignierte IPA für Commit 1d9b5af wurde mit Xcode erstellt und auf Archivstruktur, ARM64-Programm und eingebettete Anisette-Runtime geprüft. Privater Build: https://github.com/Serekay/directside/actions/runs/40083954661 .

Lokale iOS-Authentifizierung ist über Swift-AnisetteKit-TCI und den Rust-C-Callback implementiert. Auf dem macOS-Buildrechner bestanden echte Apple-Provisionierung und wiederholte OTP-Erzeugung ohne Apple-ID. Das bestätigt den lokalen Anisette-Weg, jedoch keine Apple-ID-Anmeldung oder Selbsterneuerung auf dem iPhone. Kein Fremdserver-Fallback. **Aktueller Blocker für den Hardwaretest:** Windows-Anmeldung scheitert noch am Entwicklertoken; der angepasste Client muss am Account geprüft werden.

Die optionale Windows-Einrichtung für LiveContainer und der Quellcode für die lokale Zertifikatsübergabe sind vorhanden. Standalone-Installation, Übertragung, iOS-Schlüsselbundimport, Übergabe an LiveContainer und dessen JIT-less-Test sind noch gemeinsam am Gerät zu prüfen. Ein integriertes LiveContainer-Laufzeitsystem ist nicht umgesetzt.

## Vor einer Freigabe offen

- Frische lokale Apple-Anmeldung und Zwei-Faktor-Bestätigung.
- Signierung und Erstinstallation der eigenen IPA samt Remote-Pairing.
- Lokale iOS-Authentifizierung am echten Gerät einschließlich 2FA und Wiederherstellung der Sitzung prüfen.
- App-Installation, Update mit Datenerhalt und Selbsterneuerung über LocalDevVPN.
- Gleichzeitiger Hardwaretest mit mehreren Geräten; bisherige Trennungsprüfungen verwenden simulierte Ereignisse.
- LiveContainer-Installation, Zertifikatseinrichtung und Start einer Gast-App.

Windows wird ausschließlich lokal gebaut. iPhone-Actions sind nur manuell auslösbar. Das GitHub-Repository bleibt privat; es gibt keine öffentliche Veröffentlichung und keinen Release.
