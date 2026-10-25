# DirectSide project instructions

- Keep this project separate from empires-private-server.
- Preserve the approved Magazin design and individual DirectSide icon.
- Keep GitHub private. Do not create releases, publish publicly, change repository visibility or submit to an app store without the owner's explicit release instruction.
- Never commit Apple credentials, session tokens, signing identities, provisioning profiles, pairing records or real device identifiers.
- Do not claim that a successful build proves successful device installation or self-renewal. State which hardware checks actually ran.
- The owner has a normal Apple ID. LocalDevVPN remains external; seven-day and other Apple limits still apply.
- LocalDevVPN setup belongs exclusively to the iPhone introduction/settings. Do not show its install prompt, QR code or missing-status badge in Windows, or require it before the USB installation of DirectSide.
- Keep the Windows start page focused on DirectSide. Offer other IPA installs through a visible plus button and a separate page. Show Developer Mode guidance when the installation flow actually needs it, without a persistent start-page badge or warning.
- Windows settings are for language, updates and choosing Apple Account or an existing certificate. Keep technical diagnostics and redundant app shortcuts out of this page. Help shows the current next step with usable actions; call the diagnostic log “Protokoll”/“Log”, not “Aktivität”/“Activity”.
- Keep account quotas next to the account and app counts next to the selected device. Background refreshes retain the last confirmed values while pending; clear them on device changes, disconnection or actual verification failure. Do not show idle status badges in the footer.
- Setup polling must not replace a user-opened settings/help/log/details page. Back returns explicitly to the current setup step. Keep the manual USB recheck as a clearly named refresh icon on the disconnect screen; no generic “Check again” or “Show switch” buttons in the Developer Mode guide.
- Setup copy describes the user's next action, not polling intervals. After an iPhone restart, explain reconnecting USB if the device is not detected and confirming Trust if prompted.
- USB repair requires an explicit click after a localized explanation of the Windows permission prompt. Never automatically elevate on polling. Treat denied/dismissed permission as cancellation, and only report recovery after real Apple USB enumeration succeeds. Restart the Apple service as well as the single validated Apple composite device; never reset hubs or unrelated hardware.
- Use branch names beginning with codex/.
- Build Windows locally with scripts/build-windows.ps1. GitHub Actions is only for manually requested iPhone builds; do not add Windows CI or automatic runs.
- Preserve the compact iLoader-inspired Qt Quick desktop: custom window chrome, status badges, icon settings, inline authentication and no scrollbar in the main view.
- Desktop defaults to English; persist optional German selection. Missing states are red, warnings/unknown states yellow, successful checks green. Keep setup help in the overflow menu and app/device state scoped to the selected device.
- No remote Anisette fallback. The local Windows provider must not be presented as a working local iOS implementation.
- Every automated setup step must have a clear, localized manual fallback shown at that step if automation fails or its result cannot be verified (including different iOS versions/layouts). Never imply that an unverified step is complete. Use semantic identifiers for native navigation, not localized captions or fixed row indexes. Do not repeatedly reopen an untrusted app while waiting for the user's approval.

- The developer-team trust step is instructions only. Never remotely launch DirectSide or open/navigate iPhone Settings from the Windows setup, including retries, polling, reconnects and restored setup. Finishing this guide is a user acknowledgement, not proof of successful launch.
