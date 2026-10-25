# Entwicklung

## Voraussetzungen

- Rust stable mit Cargo.
- Windows: MSVC-Build-Tools oder ein passend eingerichtetes GNU/LLVM-Toolchain-Setup.
- iOS: macOS mit Xcode, XcodeGen und dem Rust-Target `aarch64-apple-ios`.
- Windows-Oberfläche: Python 3.13 oder neuer, PySide6/Qt Quick und PyInstaller (Versionen in `ui/requirements.txt`).
- Windows-Build: `scripts/prepare-mac-runtime.py` bereitet die hashgeprüfte Mac-CoreADI aus Apples iTunes-Download in `bin/apple` vor. 7-Zip wird nur zur Vorbereitung auf dem Build-PC benötigt. Die fertige Anwendung benötigt keine separate iTunes-/Emulatorinstallation.

## Windows

```powershell
.\scripts\build-windows.ps1
# Nur Oberfläche neu packen, vorhandenen Signierkern verwenden:
.\scripts\build-windows.ps1 -ReuseEngine
```

Der Build läuft lokal, führt die Tests aus und schreibt `dist/DirectSide.exe`. Die IPA liegt daneben. Für den lokalen GNU/LLVM-Compiler wird `libunwind.dll` mitgepackt. Die ignorierte `.cargo/config.toml` enthält nur lokale Compilerpfade.

`scripts/prepare-windows-bootloader.py` baut den verifizierten PyInstaller-Starter gemäß offizieller Unicorn-Kompatibilitätsanleitung mit `--no-cfg`; Windows-Schutzrichtlinien bleiben unverändert. Standard ist die lokale LLVM-MinGW-Toolchain, alternativ `DIRECTSIDE_BOOTLOADER_CC` oder MSVC. Die Paketkonfiguration verwendet diesen Starter nur für DirectSide. `-OutputDirectory build/local-mac-auth` erlaubt einen Testbau, während eine ältere EXE geöffnet ist.

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

## GitHub release contract

The updater reads `GET /repos/Serekay/directside/releases/latest`: published stable releases only, never drafts, Actions artifacts or source snapshots. Each approved tag must be a new `vMAJOR.MINOR.PATCH` version. Bump `ui/updates.py:VERSION`, Cargo and iOS app versions before building; never replace an existing version with different binaries.

After the owner's explicit release approval, attach `DirectSide.exe` (built locally) and `DirectSide.ipa` (manually built on macOS) to the same tag. GitHub's API must expose a SHA-256 digest for each asset. The app verifies that digest and size before using the download, validates the IPA's main bundle ID, and strips Authorization before following signed asset-CDN redirects. Build artifacts are not releases and do not trigger updates. No Windows CI was added.

For private access use Settings → Updates with a fine-grained token limited to this repository and Contents: Read. It is saved with user-scoped Windows DPAPI, never to preferences, logs or the repository. No GitHub account credential is sent to Apple or to the iPhone. On the development machine only, an existing project-local gh login can be read without adding a runtime dependency. Public access also works without a token if visibility is changed by the owner in the future.

The iPhone updater uses the same release contract, with a separate token entered on
the iPhone and saved in its Keychain. It strips credentials on CDN redirects,
checks the asset size/SHA-256, then asks the Rust core to validate the main app ID
and release version before signing. The signed ID must match the running app so a
team change cannot silently create a second installation. A pending record and
verified IPA survive the app being replaced; the next matching-version launch
atomically promotes that IPA to the original used for renewal. No release or
iPhone build is triggered by these changes.

## iPhone screenshots for the README

`iphone-control` additionally inspects the foreground app's accessibility
elements over the trusted USB connection and activates an exact label. It uses
the accessibility audit daemon's RSD check-in and DTX protocol, without
installing an automation app or registering another App ID. Protocol reference:
[pymobiledevice3 accessibility audit](https://github.com/doronz88/pymobiledevice3/blob/master/pymobiledevice3/services/accessibilityaudit.py).

```powershell
cargo run --release --example iphone-control --features iphone-control -- list
cargo run --release --example iphone-control --features iphone-control -- press 'Quellen, Button, Tab'
cargo run --release --example iphone-control --features iphone-control -- focus '9 / 10'
```

Open DirectSide on the unlocked phone first. Inspect labels before activating
them and verify navigation with a screenshot. A successfully sent activation
alone does not prove that the view changed. This helper is separate from the
shipped app; coordinate swipes and text input are not implemented.
`focus` only moves accessibility focus so screenshots can show the desired
part of a scrolling view. `iphone-screenshot --launch` opens the unique installed
DirectSide through Instruments; it does not install or replace it.

The optional development example `iphone-screenshot` captures one PNG over the
trusted USB connection. It uses the Instruments screenshot channel, including
CoreDeviceProxy/RSD on newer iOS versions. It does not install a developer image,
collect photo-library files, distribute screenshots or add code to the app UI.
Exactly one unlocked, trusted iPhone must be connected.

With the same local Rust environment used for Windows builds:

```powershell
cargo run --release --example iphone-screenshot --features iphone-screenshots -- --probe
cargo run --release --example iphone-screenshot --features iphone-screenshots -- --installed-version
cargo run --release --example iphone-screenshot --features iphone-screenshots -- build/iphone-discover.png
```

The probe only opens the screenshot channel. For a capture, first open DirectSide
on the phone and display the intended view. Review the resulting PNG for account
details and private source addresses before copying it into `docs/screenshots/`
and referencing it from the README. The current device passed the channel probe;
capture of the newly installed build is still pending.

Windows updates stage in LocalAppData/DirectSide/updates. The staged EXE runs its own --apply-update entry point, waits for the original Qt process to stop and preserves DirectSide.previous.exe before replacing the original file. Short retries accommodate PyInstaller's outer process cleanup. If replacement or process launch fails, the previous EXE is retained/restored. Credentials and settings are not replaced. Authentication/install operations defer the restart. Locked files or an unwritable installation folder produce an update failure rather than elevation. A successful process launch is not a post-launch health guarantee. Actual release-to-release upgrades still require a hardware check after the first release is approved.
