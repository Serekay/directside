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
- Use branch names beginning with codex/.
- Build Windows locally with scripts/build-windows.ps1. GitHub Actions is only for manually requested iPhone builds; do not add Windows CI or automatic runs.
- Preserve the compact iLoader-inspired Qt Quick desktop: custom window chrome, status badges, icon settings, inline authentication and no scrollbar in the main view.
- Desktop defaults to English; persist optional German selection. Missing states are red, warnings/unknown states yellow, successful checks green. Keep setup help in the overflow menu and app/device state scoped to the selected device.
- No remote Anisette fallback. The local Windows provider must not be presented as a working local iOS implementation.
- Every automated setup step must have a clear, localized manual fallback shown at that step if automation fails or its result cannot be verified (including different iOS versions/layouts). Never imply that an unverified step is complete. Use semantic identifiers for native navigation, not localized captions or fixed row indexes. Do not repeatedly reopen an untrusted app while waiting for the user's approval.
