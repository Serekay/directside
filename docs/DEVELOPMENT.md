# Entwicklung

## Voraussetzungen

- Rust stable mit Cargo.
- Windows: MSVC-Build-Tools oder ein passend eingerichtetes GNU/LLVM-Toolchain-Setup.
- iOS: macOS mit Xcode, XcodeGen und dem Rust-Target `aarch64-apple-ios`.
- Windows-Oberfläche: Python 3.13 oder neuer, PySide6/Qt Quick und PyInstaller (Versionen in `ui/requirements.txt`).
- Windows-Build: Apples CoreADI64.dll aus x64-iTunes. Die private Paketkonfiguration übernimmt sie in `bin/apple`; sie bleibt aus Git ausgeschlossen.

## Windows

```powershell
.\scripts\build-windows.ps1
# Nur Oberfläche neu packen, vorhandenen Signierkern verwenden:
.\scripts\build-windows.ps1 -ReuseEngine
```

Der Build läuft lokal, führt die Tests aus und schreibt `dist/DirectSide.exe`. Die IPA liegt daneben. Für den lokalen GNU/LLVM-Compiler wird `libunwind.dll` mitgepackt. Die ignorierte `.cargo/config.toml` enthält nur lokale Compilerpfade.

Die Qt-Quick-Oberfläche liegt in `ui/Main.qml`, die Python-Anbindung in `ui/desktop.py`. Eigene Titelleiste, verschiebbares und skalierbares Fenster, kompakte Status-Badges, Icon-Einstellungen und integrierte Bestätigungen ersetzen die frühere Tkinter-Oberfläche. Die normale Ansicht hat keine Scrollbar.

## iPhone

Windows-Lokalisierung: `ui/en.json` und `ui/i18n.py`, QML verwendet `win.t(...)`. Englisch ist Standard; Sprache und Apple-ID werden gespeichert. Unbekannte technische Detailmeldungen bleiben unverändert. `ui/components.py` enthält Komponentenprüfung und festgelegte Downloads mit Prüfsummen.

```sh
rustup target add aarch64-apple-ios
python3 scripts/prepare-anisette-runtime.py
cargo build --locked --release --lib --target aarch64-apple-ios
cd ios
xcodegen generate
cd ..
xcodebuild -project ios/DirectSide.xcodeproj -scheme DirectSide -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
mkdir -p package/Payload
cp -R build/Build/Products/Release-iphoneos/DirectSide.app package/Payload/
cd package
ditto -c -k --sequesterRsrc --keepParent Payload DirectSide.ipa
```

Der private GitHub-Actions-Workflow führt nur diese iPhone-Schritte aus, ausschließlich nach manuellem Start, und legt kurzlebige Artefakte ab. Zusätzlich prüft DirectSideAnisetteProbe auf macOS die lokale TCI-Provisionierung und wiederholte OTP-Erzeugung ohne Apple-ID. Das Vorbereitungsskript prüft den Apple-Download und beide Bibliotheken per SHA-256. AnisetteKit ist auf eine Revision festgelegt; Herkunft und Lizenz stehen in THIRD_PARTY.md. Windows wird dort nicht gebaut. Das ist kein GitHub-Release und keine Veröffentlichung im App Store.

## Tests vor Freigabe

1. Build, Quellformat-Tests und Rust-Protokolltests müssen erfolgreich sein.
2. USB-Erkennung am angeschlossenen Gerät; Abziehen erzeugt eine verständliche Meldung.
3. Apple-Anmeldung und 2FA, ohne Passwort oder Token in Protokollen.
4. Erstinstallation der eigenen IPA samt Remote-Pairing.
5. Quellenimport über Adresse und Kamera-QR, echte Icons und Screenshots, Versionsauswahl nach iOS-Kompatibilität.
6. Installation einer Test-App und Update aus derselben Quelle bei unveränderten Nutzerdaten.
7. Erneuerung einer App und zuletzt der eigenen App bei verbundenem LocalDevVPN.
8. Erneuter Start: Quelle, App-Liste und Schlüsselbund-Sitzung bleiben erhalten.

Erfolg nur für tatsächlich ausgeführte Tests dokumentieren. Keine Release-Freigabe aus einem grünen Build ableiten.

## Paketprüfung

Die versionierte Konfiguration liegt in `packaging/DirectSide.spec`. Der lokale Build isoliert PATH von fremden Toolchains und nimmt keine fremde ICU-DLL mit auf. Nach dem Packen startet er die tatsächliche EXE mit `--smoke-test` und prüft Qt, QML, Fenster-Icon, Signierkern und tatsächliche lokale Anisette-Erzeugung. Der Bericht liegt unter `build/smoke-test.json`. Apple-Zugangsdaten werden nicht benötigt; eine unprovisionierte lokale Laufzeit kann Apples eigene Provisionierungsendpunkte kontaktieren.
