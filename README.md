# DirectSide

Sideload with your own Apple ID. DirectSide combines a Windows setup app with a native iPhone app for browsing sources, installing apps and managing updates.

**Development preview.** Windows includes local Apple authentication; the owner has confirmed a successful Apple-ID sign-in. On-device sign-in, self-renewal and LiveContainer setup still need device testing.

## A clear view of your devices

- Automatically detect connected iPhones and iPads.
- Browse installed apps with their icons and separate app-slot counts for each device.
- Set up missing components from the Windows app.
- Import app sources by QR code or URL, with descriptions, screenshots and updates.
- Choose English or German and keep your preference.
- Load the latest released DirectSide IPA from GitHub, or choose your own IPA.
- Get Windows update notifications and update with a restart from the app.

| Windows setup | Installed apps |
|:---:|:---:|
| [![DirectSide Windows setup in English](docs/screenshots/windows-setup.png)](docs/screenshots/windows-setup.png) | [![Installed apps in English](docs/screenshots/windows-apps.png)](docs/screenshots/windows-apps.png) |

*English interface, shown with demonstration account and device data.*

## Get started

1. Once a version is approved, download **DirectSide.exe** from [Releases](https://github.com/Serekay/directside/releases). No release is available yet.
2. Open DirectSide, connect and unlock your iPhone or iPad, then tap **Trust** on the device.
3. Sign in with your Apple ID, choose the target device, select **Install DirectSide**. It downloads the latest released IPA and installs it on the selected device. Use **Other IPA → Install IPA** for a local file.
4. Install LocalDevVPN using the QR code if requested, then follow its setup instructions on your device.

Need a hand? Open **? → Help**. Optional LiveContainer setup is under **Settings → LiveContainer**.

DirectSide checks stable GitHub releases at startup and every six hours. **Update** downloads and verifies the new Windows app, then restarts it. While the repository is private, configure a fine-grained GitHub token with **Contents: Read** for this repository under **Settings → Updates**. It is encrypted for your Windows user; no shared token is included. The existing project-local GitHub CLI login can also be reused on the development PC.

## Before you start

You need Windows and an iPhone or iPad running iOS/iPadOS 17 or later. A free Apple ID allows **three sideloaded apps per device**, with signatures lasting **seven days**. DirectSide uses one slot. LocalDevVPN is a separate App Store app; LiveContainer is optional.

Your password is not saved. Authentication sessions and signing keys are stored in the system credential store.

## Development

[Build guide](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Test status](docs/TESTSTATUS.md) · [Changelog](CHANGELOG.md)

Built with [isideload](vendor/README-DirectSide.md) and idevice. [License](LICENSE).
