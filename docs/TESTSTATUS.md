# Teststand vom 24. Oktober 2026

Diese Datei dokumentiert den Entwicklungsstand, keine Release-Freigabe.

## Aktueller Windows-Pakettest

Die tatsächliche `dist/DirectSide.exe` wurde mit `--smoke-test` gestartet: QtCore lädt, die QML-Oberfläche lädt, das Fenster-Icon ist vorhanden, die eigene Titelleiste ist aktiv, und der mitgelieferte Signierkern meldet `ready` und beendet sich mit Exit-Code 0. Der lokale Build bricht ab, wenn einer dieser Schritte fehlschlägt. Das Prüfprotokoll liegt in `build/smoke-test.json`.

Der vorherige QtCore-DLL-Fehler entstand durch eine fremde `icuuc.dll` aus einer PDF-Toolchain im Build-PATH. Der Build isoliert jetzt die Suchpfade; die versionierte Paketkonfiguration schließt diese Fremdbibliothek aus.

Alte Paketvarianten, generierte Specs im Projektstamm, alte Build-Verzeichnisse und nicht mehr benötigte Downloadarchive wurden nach `F:\Projekte\_archive\DirectSide-alt-20261024` verschoben. Das aktuelle Paket liegt ausschließlich direkt unter `dist`.

## Erfolgreich geprüft

- Rust-Kern unter Windows kompiliert; zwei Tests für HTTPS-Dienstadressen und das Drei-App-Limit bestanden. Eine bereits installierte App darf bei drei belegten Plätzen weiter erneuert werden; eine vierte wird abgelehnt.
- Zehn Python-Tests für IPA-Hauptbundle-Auswahl, mehrdeutige Pakete, bereinigte Fehlermeldungen, lokale Account-Voreinstellungen, Code-Validierung und integrierte Qt-UI-Zustände und das Laden der rahmenlosen QML-Ansicht bei Mindestgröße bestanden. Die UI-Tests verwenden ausschließlich simulierte Protokollereignisse, keine Apple-Zugangsdaten.
- iPhone-Kern für `aarch64-apple-ios` und native SwiftUI-App erfolgreich über Xcode gebaut; Quellenformat-Tests im macOS-Build bestanden.
- Unsigned-IPA heruntergeladen und Archivstruktur, Bundle-ID, Versionsnummer, Mindest-iOS und ARM64-Mach-O-Datei geprüft.
- Lokal gepackte Windows-EXE gestartet: Oberfläche, eigenes Icon, eingebetteter Signierkern und automatische IPA-Erkennung funktionieren.
- USB-Erkennung eines angeschlossenen iPhones und lesender Abruf der installierten App-Metadaten funktionieren.
- Eine bereits vom Benutzer aufgebaute Windows-Sitzung wurde beim Start der neuen EXE aus dem Schlüsselbund wiederhergestellt. Eine neue Apple-Anmeldung und Zwei-Faktor-Bestätigung wurden dadurch nicht erneut geprüft.

Der erste iPhone-Build ist unter [GitHub Actions](https://github.com/Serekay/directside/actions/runs/40075822402) nachvollziehbar. Windows-Builds erfolgen inzwischen ausschließlich lokal; ältere überflüssige Actions-Läufe wurden abgebrochen. iPhone-Builds sind nur noch manuell auslösbar.

## Noch am Gerät zu prüfen

- Apple-Anmeldung und Zwei-Faktor-Bestätigung mit dem eigenen Account.
- Erstinstallation samt Remote-Pairing und Start der signierten DirectSide-App.
- Quellenimport mit echter Kamera, App-Download und Installation über LocalDevVPN.
- Update mit Erhalt der App-Daten, Sitzung nach Neustart und Selbsterneuerung.
- LiveContainer-Übergabe, dessen Zertifikatseinrichtung und Kompatibilität einzelner Gast-Apps.

LiveContainer ist in diesem Stand separat. Ein integriertes Laufzeitsystem und eine automatische Zertifikatsübergabe an LiveContainer sind noch nicht umgesetzt. Die Übergabe eines Download-Links ist kein Nachweis, dass die Gast-App darin funktioniert.

Das Repository bleibt privat. Es wurde keine öffentliche Veröffentlichung und kein Release erstellt.
