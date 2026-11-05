# Architecture

## Components

- **Windows:** Qt Quick interface in `ui/`, packaged with PyInstaller. A separate Rust engine exchanges commands and events over process pipes.
- **iPhone:** SwiftUI interface in `ios/DirectSide/`. A C ABI connects it to the shared Rust signing core on a worker thread.
- **Shared core:** `src/` uses the vendored `isideload` library for Apple authentication, developer teams, certificates, provisioning and code signing. `idevice` supplies USB and on-device installation services.

## Authentication and storage

Apple's Mac CoreADI runtime executes locally under Unicorn on Windows and a TCI interpreter on iPhone. Runtime preparation verifies the pinned download and library hashes. No remote Anisette server is used.

Windows protects the local machine context with DPAPI and stores account sessions and signing identities in the Windows credential store. iPhone uses the device Keychain. Non-secret settings such as language and the saved email are separate from authentication state.

## Installation and renewal

Windows downloads the IPA from the current official release, verifies its size, SHA-256 and main bundle identifier, then signs it for the selected device. Custom IPAs follow a separate file-selection flow. Initial DirectSide installation transfers the device's pairing material, signing identity, account context and original IPA over trusted USB.

On iPhone, LocalDevVPN provides the local network route. The pairing record authenticates the connection; the shared core uses the RSD services to transfer and install signed apps.

Renewal re-signs the original IPA for the same team and application identity. Updates install a newer version. DirectSide renews itself last during bulk renewal because iOS may terminate the running app when replacing it.

## Sources and installed apps

Sources use the AltStore/SideStore JSON format over HTTP or HTTPS. The catalog supports version lists, descriptions, icons, screenshots and app compatibility. Adding a source or scanning its QR code does not install an app automatically.

Managed app records retain source association, original bundle identifier, installed version/build and a cached original IPA. Update badges compare compatible source versions with installed metadata. Device responses are scoped to the selected device so stale results cannot update another device's UI.

## LiveContainer

DirectSide installs the upstream standalone IPA after hash verification and can transfer an encrypted signing certificate locally. LiveContainer runs compatible guest apps inside its own container; it remains a separate application.

If LiveContainer's renewal IPA is missing, DirectSide can retrieve the pinned standalone package and renew the existing installation. A changed signing team or ambiguous installation stops replacement rather than creating a different app. LiveContainer guest data belongs to its container and is not read by DirectSide.

## Releases

Both apps read published stable releases from this repository. The update contract requires `DirectSide.exe`, `DirectSide.ipa` and `SHA256SUMS.txt`. Windows is built locally; the manually dispatched macOS workflow builds an unsigned IPA. Account sign-in, device pairing and personal signing happen on the user's own devices.
