# DirectSide

Sideload with your own Apple ID. Set up your iPhone or iPad from Windows, then browse app sources, install IPAs and manage signatures on your device.

[Download for Windows](https://github.com/Serekay/directside/releases/latest/download/DirectSide.exe) | [Download IPA](https://github.com/Serekay/directside/releases/latest/download/DirectSide.ipa) | [Releases](https://github.com/Serekay/directside/releases)

## Windows and iPhone, together

- Automatic device detection, app icons and separate app-slot counts for each device.
- Local Apple sign-in with saved sessions and inline verification.
- One-button DirectSide installation, automatic USB pairing and setup repair. Install your own IPAs too.
- HTTP and HTTPS sources with QR import, descriptions, screenshots and updates.
- Install from sources or import an IPA on iPhone. Renew signatures and manage apps and certificates.
- Optional LiveContainer installation with automatic certificate transfer and JIT-less configuration.
- Free and paid Apple Developer teams, or imported P12 certificates with matching provisioning profiles.
- English and German, with saved language preferences in both apps.
- Windows and iPhone update checks with verified downloads from published releases.

| Windows setup | Installed apps |
|:---:|:---:|
| [![Windows setup in English](docs/screenshots/windows-setup.png)](docs/screenshots/windows-setup.png) | [![Installed apps in English](docs/screenshots/windows-apps.png)](docs/screenshots/windows-apps.png) |

*Screenshots use demonstration account and device data.*

## Get started

1. Download and open **DirectSide.exe**. Connect your device by USB, unlock it and accept **Trust** if requested.
2. Sign in with your Apple ID and select your device. For an existing certificate, use **Settings > Components > Signing** to import the P12 file and matching `.mobileprovision` files instead.
3. Select **Install DirectSide**. The latest released IPA is downloaded, signed and installed; pairing, the original IPA and signing files are transferred automatically. Use **Other IPA** for a local file.
4. **Before opening DirectSide for the first time, enable Developer Mode:** open **Settings > Privacy & Security > Developer Mode**, turn it on, restart the iPhone, unlock it and confirm **Turn On**. If the switch is missing, install the first development app from Windows and check again, or use Windows help to reveal the switch. If requested, also trust your developer profile under **Settings > General > VPN & Device Management**. Distribution profiles may not require Developer Mode.
5. Install **LocalDevVPN** using the displayed QR code and follow its setup instructions. Connect it before on-device installation or signature renewal. Its status is in DirectSide **Settings**; an installation attempt without a connection explains what to do.
6. Open DirectSide on your device, sign in or select your imported certificate and add a source using **+**. Choose a normal installation or LiveContainer for supported apps.

On iPhone, pull down to refresh sources and swipe left to remove one. **My Apps** shows signature days remaining and updates on the affected app rows. Swipe left or touch and hold an installed app to delete it and its data; this frees a free-account app slot. Regular App Store apps remain managed by iOS. Windows also lists only sideloaded apps. **Settings** holds your account, signing method, Developer Mode instructions, language, connection and updates. Windows help is under **?**.

For LiveContainer, install it from DirectSide. After installation, DirectSide opens LiveContainer with the matching certificate; the certificate enables JIT-less automatically. When installing from Windows, open DirectSide on the iPhone to complete that handoff. **Settings > LiveContainer > Transfer Certificate** remains available to repair an interrupted handoff. The LiveContainer diagnostic is useful if a guest app fails to start; it is not an additional mode switch. Compatibility and certificate capabilities still matter.

## Requirements and limits

Windows and iOS/iPadOS **17 or later**. A free Apple ID allows **3 sideloaded apps per device**, **10 new App IDs per 7 days** and **7-day signatures**. DirectSide uses one app slot; LiveContainer uses another. Apple's certificate quota is separate: one certificate can sign multiple apps, and deleting an app does not revoke its certificate.

Paid Apple Developer teams use their actual provisioning rules; DirectSide does not apply the free three-app limit to their profiles. Import currently supports RSA signing identities, matching the underlying signer. Imported certificates need a private key and valid profiles for the app, its extensions and this device (unless the profile allows all devices). Add multiple profiles when extensions use separate app IDs. Explicit profiles for unrelated apps cannot be used to sign DirectSide. Import validates the key/certificate match, certificate and profile dates and profile membership; the iPhone still verifies Apple's trust and revocation rules during installation. Importing does not require signing into the certificate provider.

Apple authentication runs locally. Your password is not saved; authentication sessions and signing keys use the system credential store. LocalDevVPN is a separate App Store app.

This repository is private. Release downloads require repository access. Save a repository-scoped GitHub token with **Contents: Read** under **Settings > Updates** on Windows or **Settings > DirectSide Updates** on iPhone. Each device stores its own token securely; it is not bundled or automatically copied. The iPhone checks at startup (at most every six hours) and offers an available update, or you can check manually in Settings. Updates are downloaded, checked against GitHub's size and SHA-256, signed and installed on the iPhone over LocalDevVPN. The verified new original IPA is retained for later renewal. You do not need to reconnect to Windows for each update. If DirectSide's signature has already expired and iOS cannot open it, repair from Windows is still necessary.

## Project

The published release remains **0.1.0, build 5**. The new **0.1.0, build 6** test IPA is built and available locally at `dist/DirectSide.ipa`; it has not been published as a release. To test it, choose that file using **Other IPA** in Windows. The release-install button continues to download the published release. Signature renewal on iPhone reuses its stored original IPA; it does not fetch a new app version. Installing the new IPA over the existing app with the same signing team updates it while normally preserving its data. Previous Windows and iPhone sign-in, installation and USB setup transfer were confirmed on hardware. The new self-updater, imported signing and automatic LiveContainer handoff still require owner verification; see [test status](docs/TESTSTATUS.md).

[Build guide](docs/DEVELOPMENT.md) | [Architecture](docs/ARCHITECTURE.md) | [Changelog](CHANGELOG.md) | [Third-party notices](THIRD_PARTY.md) | [License](LICENSE)
