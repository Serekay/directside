# DirectSide

Sideload with your own Apple ID. DirectSide combines a Windows setup app with a native iPhone app for browsing sources, installing apps and managing updates.

**Development preview.** On-device Apple sign-in and self-renewal are still in development. LiveContainer setup needs device testing.

## A clear view of your devices

- Automatically detect connected iPhones and iPads.
- Browse installed apps with their icons and separate app-slot counts for each device.
- Set up missing components from the Windows app.
- Import app sources by QR code or URL, with descriptions, screenshots and updates.
- Choose English or German and keep your preference.

| Windows setup | Installed apps |
|:---:|:---:|
| [![DirectSide Windows setup in English](docs/screenshots/windows-setup.png)](docs/screenshots/windows-setup.png) | [![Installed apps in English](docs/screenshots/windows-apps.png)](docs/screenshots/windows-apps.png) |

*English interface, shown with demonstration account and device data.*

## Get started

1. Download **DirectSide.exe** and **DirectSide.ipa** from the same [release](https://github.com/Serekay/directside/releases). Keep both files in one folder.
2. Open DirectSide, connect and unlock your iPhone or iPad, then tap **Trust** on the device.
3. Sign in with your Apple ID, choose the target device and select **Install on device**. Follow the prompts.
4. Install LocalDevVPN using the QR code if requested, then follow its setup instructions on your device.

Need a hand? Open **⋯ → Help**. Optional LiveContainer setup is under **Settings → LiveContainer**.

## Before you start

You need Windows and an iPhone or iPad running iOS/iPadOS 17 or later. A free Apple ID allows **three sideloaded apps per device**, with signatures lasting **seven days**. DirectSide uses one slot. LocalDevVPN is a separate App Store app; LiveContainer is optional.

Your password is not saved. Authentication sessions and signing keys are stored in the system credential store.

## Development

[Build guide](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Test status](docs/TESTSTATUS.md) · [Changelog](CHANGELOG.md)

Built with [isideload](vendor/README-DirectSide.md) and idevice. [License](LICENSE).
