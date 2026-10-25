# DirectSide

Install iPhone apps with your own Apple account. Set up DirectSide from Windows, then add sources, install IPAs and renew signatures directly on your iPhone.

**0.1.1 (16)**

[Download for Windows](https://github.com/Serekay/directside/releases/latest/download/DirectSide.exe) | [Download IPA](https://github.com/Serekay/directside/releases/latest/download/DirectSide.ipa) | [Releases](https://github.com/Serekay/directside/releases)

## Features

- Guided Windows setup with USB pairing and account transfer.
- App sources by address or QR code, with app details and screenshots.
- IPA installation, signature renewal and app updates on iPhone.
- Optional LiveContainer installation and certificate setup.
- Free and paid Apple Developer accounts, or your own signing certificate.
- App ID usage and signature expiry at a glance.
- English and German.

## Screenshots

| Introduction | My Apps |
|:---:|:---:|
| <img src="docs/screenshots/iphone-introduction.png" alt="DirectSide introduction" width="260"> | <img src="docs/screenshots/iphone-my-apps.png" alt="Installed apps and signature expiry" width="260"> |

| Add a source | Settings |
|:---:|:---:|
| <img src="docs/screenshots/iphone-add-source.png" alt="Add a source by address or QR code" width="260"> | <img src="docs/screenshots/iphone-settings.png" alt="DirectSide settings" width="260"> |

## Get started

1. Open **DirectSide.exe** on Windows. Connect your iPhone by USB, unlock it and confirm **Trust** if asked.
2. Sign in with your Apple account and select **Install DirectSide**. To use an existing certificate, choose **Settings > Install using** instead.
3. Follow the Windows setup guide. If required, enable **Settings > Privacy & Security > Developer Mode** on the iPhone, restart and confirm **Turn On**. DirectSide prepares the switch if it is not yet visible.
4. On the iPhone, open **Settings > General > VPN & Device Management**, select your developer team and confirm **Trust**. Then open DirectSide.
5. Follow the introduction to install and connect **LocalDevVPN**. Your Windows account is transferred automatically.
6. Add a source with **+**, then choose an app to install.

If the iPhone is not detected after restarting, reconnect the USB cable and confirm **Trust** if asked. If it remains disconnected, select **Repair connection** in Windows and approve the Windows permission prompt with **Yes**.

## LiveContainer

LiveContainer lets compatible apps share one sideloaded app slot. Install it during the introduction, then select **Complete setup** to transfer the certificate. Choose **Set up later** to skip it. You can repeat the certificate transfer under **Settings > LiveContainer**.

## Manage apps and updates

**My Apps** shows installed apps, signature expiry and available updates. Swipe left or touch and hold an app to remove it. Renew signatures before they expire.

Check for DirectSide updates in **Settings**. The iPhone also checks automatically at startup. Keep LocalDevVPN connected when installing, updating or renewing apps on the iPhone.

To update from Windows, keep the new `DirectSide.ipa` beside `DirectSide.exe` and select **Install DirectSide**. Use the same Apple account and team to retain the existing installation and app data.

## Requirements and limits

- Windows for initial setup; iOS or iPadOS **17 or later**.
- A free Apple account allows **3 sideloaded apps per device**, **10 new App IDs per 7 days** and **7-day signatures**. DirectSide and LiveContainer each use one app slot.
- Updating the same app with the same team reuses its App ID. View registered IDs in **Settings > App IDs**, or select the App ID badge in Windows.
- Paid developer accounts use their team provisioning rules.
- Imported certificates require a P12 file containing the private key and matching provisioning profiles for the app and device.

## Development

[Build guide](docs/DEVELOPMENT.md) | [Architecture](docs/ARCHITECTURE.md) | [Changelog](CHANGELOG.md) | [Third-party notices](THIRD_PARTY.md) | [License](LICENSE)
