# Teststand vom 24. Oktober 2026

Diese Datei dokumentiert den Entwicklungsstand, keine Release-Freigabe.

## Erfolgreich geprüft

- Rust-Kern unter Windows kompiliert; zwei Tests für HTTPS-Dienstadressen und das Drei-App-Limit bestanden. Eine bereits installierte App darf bei drei belegten Plätzen weiter erneuert werden; eine vierte wird abgelehnt.
- Drei Python-Tests für IPA-Hauptbundle-Auswahl, mehrdeutige Pakete und bereinigte Fehlermeldungen bestanden.
- iPhone-Kern für `aarch64-apple-ios` und native SwiftUI-App erfolgreich über Xcode gebaut; Quellenformat-Tests im macOS-Build bestanden.
- Unsigned-IPA heruntergeladen und Archivstruktur, Bundle-ID, Versionsnummer, Mindest-iOS und ARM64-Mach-O-Datei geprüft.
- Lokal gepackte Windows-EXE gestartet: Oberfläche, eigenes Icon, eingebetteter Signierkern und automatische IPA-Erkennung funktionieren.
- USB-Erkennung eines angeschlossenen iPhones und lesender Abruf der installierten App-Metadaten funktionieren.

Der erste iPhone-Build ist unter [GitHub Actions](https://github.com/Serekay/directside/actions/runs/40075822402) nachvollziehbar. Nach der Anpassung der Windows-Oberfläche wurde ein weiterer privater Build gestartet.

## Noch am Gerät zu prüfen

- Apple-Anmeldung und Zwei-Faktor-Bestätigung mit dem eigenen Account.
- Erstinstallation samt Remote-Pairing und Start der signierten DirectSide-App.
- Quellenimport mit echter Kamera, App-Download und Installation über LocalDevVPN.
- Update mit Erhalt der App-Daten, Sitzung nach Neustart und Selbsterneuerung.
- LiveContainer-Übergabe, dessen Zertifikatseinrichtung und Kompatibilität einzelner Gast-Apps.

LiveContainer ist in diesem Stand separat. Ein integriertes Laufzeitsystem und eine automatische Zertifikatsübergabe an LiveContainer sind noch nicht umgesetzt. Die Übergabe eines Download-Links ist kein Nachweis, dass die Gast-App darin funktioniert.

Das Repository bleibt privat. Es wurde keine öffentliche Veröffentlichung und kein Release erstellt.
