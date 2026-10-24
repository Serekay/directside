# Vendored isideload

Source: https://github.com/nab138/isideload, main branch snapshot retrieved 2026-10-24. Package version 0.5.0. Dependency versions are recorded in the top-level Cargo.lock.

License: MIT, see LICENSE-isideload.

Local change: `DeveloperSession::session_credentials` exposes a copy of the existing app token and account identifier to the DirectSide core. DirectSide stores them in the operating-system credential store so an existing developer session can be restored. No password is exported or stored. The export is not printed, included in error messages or passed to the Swift/JSON event bridge.

Local Windows authentication: `anisette/local/mac_windows.rs` calls DirectSide's packaged local Mac CoreADI helper over an owner-restricted Windows pipe. The helper uses the MIT emulator subset in `vendor/mac-adi-python`, verifies Apple's runtime hash, checks TLS and protects its state with Windows DPAPI. No account credentials enter the helper. The account builder requires an explicit provider and never silently chooses a remote server. iOS uses `anisette/local/callback.rs` with Swift AnisetteKit; unsupported platforms fail explicitly.

The previous Windows/iTunes profile adjustment did not resolve the user's −80046 failure. The new helper uses a consistent Mac identity from provisioning through login. Developer-service requests use the matching Xcode identity separately from GrandSlam's akd identity, following the upstream read-only Xcode token / listTeams experiment. OTP caches expire at real 30-second window boundaries. Success on the user's Apple account still requires confirmation.

The native Windows ADI implementation has been removed. Protocol references: https://github.com/Dadoum/apple-crates/tree/main/library-coreadi and https://github.com/sacca97/os-findmy-e . No remote Anisette service is used.

LiveContainer transfer: `Sideloader::livecontainer_certificate` returns an encrypted PKCS#12 archive using the existing signing identity for the selected developer team. The DirectSide core transfers this directly over USB, never through UI status events or logs. This is an explicit optional transfer and does not enable an embedded LiveContainer runtime.
