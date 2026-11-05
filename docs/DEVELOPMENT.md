# Development

## Requirements

- Rust stable and Git.
- Windows: Python 3.13 or later, Visual Studio C++ build tools or a compatible LLVM/MinGW toolchain, and 7-Zip.
- iPhone builds: macOS, Xcode, XcodeGen, CMake, pkg-config and 7-Zip.

Python dependency versions are pinned in `ui/requirements.txt`. Rust dependencies are locked in `Cargo.lock` and `vendor/mac-adi-rust/Cargo.lock`.

## Windows build

From the repository root:

```powershell
python -m venv .tools/python
New-Item -ItemType Directory -Force build | Out-Null
.\scripts\build-windows.ps1
```

The script builds the signing engine, prepares the local Apple runtime and PyInstaller bootloader, runs tests, packages the application and checks the actual EXE. Output: `dist/DirectSide.exe`. A separately downloaded IPA is not needed to use the application's **Install DirectSide** button.

To reuse an existing engine or keep the result separate:

```powershell
.\scripts\build-windows.ps1 -ReuseEngine -OutputDirectory build/desktop
```

The script uses `.tools/python/Scripts/python.exe` when present, otherwise Python on PATH. Set `DIRECTSIDE_BOOTLOADER_CC` when selecting a custom bootloader compiler. The bootloader uses PyInstaller's `--no-cfg` compatibility option for Unicorn; it does not change Windows system policy.

## iPhone build

The manual workflow in `.github/workflows/build.yml` contains the complete macOS build. To build locally from the repository root:

```sh
brew install sevenzip cmake pkgconf xcodegen
rustup toolchain install stable --profile minimal
rustup target add aarch64-apple-ios
python3 scripts/prepare-mac-runtime.py
mkdir -p ios/Resources/MacAnisetteRuntime
cp bin/apple/CoreADI.mac ios/Resources/MacAnisetteRuntime/
python3 scripts/build-ios-mac-auth.py
cargo +stable build --locked --release --lib --target aarch64-apple-ios
(cd ios && xcodegen generate)
xcodebuild -project ios/DirectSide.xcodeproj -scheme DirectSide \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
mkdir -p package/Payload
cp -R build/Build/Products/Release-iphoneos/DirectSide.app package/Payload/
(cd package && ditto -c -k --sequesterRsrc --keepParent Payload DirectSide.ipa)
python3 scripts/verify-directside-ipa.py package/DirectSide.ipa
```

The result is unsigned. Install and sign it with your own Apple account through the Windows app. Required third-party notices are in [THIRD_PARTY.md](../THIRD_PARTY.md).

## Tests

```sh
python -m pip install -r ui/requirements.txt
python -m unittest discover -s tests
cargo test --locked --lib
```

Set `QT_QPA_PLATFORM=offscreen` for headless Python/UI tests. Swift model and asynchronous source-refresh tests, plus the local authentication-runtime probe, run in the macOS workflow. Build checks do not replace device testing of login, USB setup, installation, source updates and signature renewal.

## Versions and releases

Keep these values aligned:

- `ui/updates.py`: `VERSION` and `BUILD`.
- `ios/project.yml`: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- `Cargo.toml` and the `directside-engine` entry in `Cargo.lock`.

Keep the main app identifier `com.directside.app` unchanged. Use a new semantic version and increasing build number for each release.

The updater reads published, stable `vMAJOR.MINOR.PATCH` releases. Each release contains `DirectSide.exe`, `DirectSide.ipa` and `SHA256SUMS.txt`; GitHub asset metadata must include each file's size and SHA-256 digest. Both apps validate downloads before installation. Public downloads require no GitHub account. Build artifacts and drafts are not app updates.

Windows updates retain the previous EXE so a failed replacement or restart can be rolled back. User settings and credentials are stored outside the executable.

## Localization and documentation

Windows strings are in `ui/en.json`; iPhone strings are in `ios/DirectSide/Translations.json`. Both default to English and persist the selected language.

`scripts/preview-windows.py` opens the real QML with sample account/device data and temporary preferences. It does not start authentication, device commands or update checks. Documentation screenshots must not contain real account details, device identifiers or private source addresses.

## Commit checks

Install [Gitleaks](https://github.com/gitleaks/gitleaks) and enable the included hook:

```sh
git config --local core.hooksPath .githooks
```

Use a GitHub noreply author address. Keep credentials, pairing records, signing identities, local instructions, generated reports and build outputs out of commits. See [SECURITY.md](../SECURITY.md) for vulnerability reporting and dependency limitations.
