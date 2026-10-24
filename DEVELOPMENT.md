# Entwicklung

## Voraussetzungen

- Rust stable mit Cargo.
- Windows: MSVC-Build-Tools oder ein passend eingerichtetes GNU/LLVM-Toolchain-Setup.
- iOS: macOS mit Xcode, XcodeGen und dem Rust-Target `aarch64-apple-ios`.
- Windows-Oberfläche: Python 3.13 oder neuer mit Tkinter. PyInstaller wird für das portable Paket verwendet.

## Windows

```powershell
cargo test --locked --lib --target x86_64-pc-windows-msvc
cargo build --locked --release --bin directside-engine --target x86_64-pc-windows-msvc
New-Item -ItemType Directory bin -Force
Copy-Item target/x86_64-pc-windows-msvc/release/directside-engine.exe bin/
python -m pip install pyinstaller
python -m PyInstaller --noconfirm --onefile --windowed --name DirectSide-Windows --icon assets/DirectSide.ico --add-data 'assets;assets' --add-binary 'bin/directside-engine.exe;bin' ui/app.py
```

Für das lokale GNU/LLVM-Setup liegt eine ignorierte `.cargo/config.toml` vor. Sie enthält ausschließlich lokale Compilerpfade und wird nicht hochgeladen.

## iPhone

```sh
rustup target add aarch64-apple-ios
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

Der private GitHub-Actions-Workflow führt dieselben Schritte aus und legt kurzlebige Artefakte ab. Das ist kein GitHub-Release und keine Veröffentlichung im App Store.

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
