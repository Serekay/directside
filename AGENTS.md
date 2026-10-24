# DirectSide project instructions

- Keep this project separate from empires-private-server.
- Preserve the approved Magazin design and individual DirectSide icon.
- Keep GitHub private. Do not create releases, publish publicly, change repository visibility or submit to an app store without the owner's explicit release instruction.
- Never commit Apple credentials, session tokens, signing identities, provisioning profiles, pairing records or real device identifiers.
- Do not claim that a successful build proves successful device installation or self-renewal. State which hardware checks actually ran.
- The owner has a normal Apple ID. LocalDevVPN remains external; seven-day and other Apple limits still apply.
- Use branch names beginning with codex/.
- Build Windows locally with scripts/build-windows.ps1. GitHub Actions is only for manually requested iPhone builds; do not add Windows CI or automatic runs.
- Preserve the compact iLoader-inspired Qt Quick desktop: custom window chrome, status badges, icon settings, inline authentication and no scrollbar in the main view.
