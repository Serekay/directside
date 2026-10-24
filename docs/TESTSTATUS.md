# Teststand vom 24. Oktober 2026

Entwicklungsstand, keine Release-Freigabe.

## Windows

- Rust-Kern lokal kompiliert. Zwei Tests prüfen das Drei-App-Limit samt Erneuerung bestehender Apps und die Erkennung anhand korrekter Bundle-IDs.
- 19 Python-Tests bestanden: IPA-Auswahl, Voreinstellungen ohne Passwort, lokale Anmeldung, Komponentenprüfung, Hashprüfung, integrierte Bestätigungen, automatisches Gerätescannen, getrennte Gerätezustände, Icon-Cache und gespeicherte Sprachwahl mit Englisch als Standard.
- Die echte gepackte EXE wurde mit --smoke-test gestartet: Qt, QML, Fenster-Icon, eigene Titelleiste, Signierkern und tatsächliche lokale Anisette-Erzeugung erfolgreich. Bericht: build/smoke-test.json.
- CoreADI erzeugt lokal Machine Data und OTP. Es wird kein Fremd-Anisette-Dienst verwendet. Die alte gespeicherte Developer-Sitzung wurde von Apple als abgelaufen zurückgewiesen (1100); eine frische Anmeldung ist noch zu prüfen.
- Am angeschlossenen Gerät wurden 191 Benutzer-Apps gelesen. LocalDevVPN wurde erkannt; LiveContainer war nicht vorhanden. Drei angefragte echte App-Icons wurden erfolgreich von SpringBoard Services gelesen.
- Offizielle LiveContainer-Standalone-IPA 3.8.0 heruntergeladen; SHA-256 und Haupt-Bundle-ID geprüft. Keine Installation oder Zertifikatsübertragung auf dem Gerät vorgenommen.
- Apple-USB-Dienst war auf diesem PC bereits installiert und gestartet. Deshalb wurde keine Neuinstallation ausgelöst. Download-/Prüf-/Startpfade wurden mit Testdaten geprüft; ein kompletter Installerlauf auf einem unvorbereiteten PC steht aus.
- Oberfläche auf Mindestgröße 960 × 680 in Deutsch und Englisch geprüft: kurze VPN-Karte, farbige Status-Badges, Hilfe aus dem ⋯-Menü, Einstellungen und App-Kacheln ohne Haupt-Scrollbar.

Der frühere QtCore-DLL-Fehler kam von einer fremden ICU-DLL im Build-PATH. Der lokale Paketbau isoliert diesen Pfad und schließt die fremde DLL aus.

## iPhone und LiveContainer

Der frühere iPhone-Build wurde mit Xcode erstellt und die unsignierte IPA auf Archivstruktur und ARM64-Programm geprüft. Die danach geänderten Swift-Pfade für die lokale Zertifikatsübergabe sind noch nicht neu gebaut oder am Gerät geprüft.

**Blocker:** Die lokale Authentifizierung ist derzeit nur für Windows implementiert. Unter iOS gibt es keinen lokalen Provider und ausdrücklich keinen Remote-Fallback. iPhone-Anmeldung und Selbsterneuerung sind deshalb noch nicht funktionsfähig freigegeben. Die ältere IPA entspricht nicht der aktuellen Anforderung an lokale Authentifizierung.

Die optionale Windows-Einrichtung für LiveContainer und der Quellcode für die lokale Zertifikatsübergabe sind vorhanden. Standalone-Installation, Übertragung, iOS-Schlüsselbundimport, Übergabe an LiveContainer und dessen JIT-less-Test sind noch gemeinsam am Gerät zu prüfen. Ein integriertes LiveContainer-Laufzeitsystem ist nicht umgesetzt.

## Vor einer Freigabe offen

- Frische lokale Apple-Anmeldung und Zwei-Faktor-Bestätigung.
- Signierung und Erstinstallation der eigenen IPA samt Remote-Pairing.
- Lokale iOS-Authentifizierung implementieren und neuen iPhone-Build prüfen.
- App-Installation, Update mit Datenerhalt und Selbsterneuerung über LocalDevVPN.
- Gleichzeitiger Hardwaretest mit mehreren Geräten; bisherige Trennungsprüfungen verwenden simulierte Ereignisse.
- LiveContainer-Installation, Zertifikatseinrichtung und Start einer Gast-App.

Windows wird ausschließlich lokal gebaut. iPhone-Actions sind nur manuell auslösbar. Das GitHub-Repository bleibt privat; es gibt keine öffentliche Veröffentlichung und keinen Release.
