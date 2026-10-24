# Vendored isideload

Source: https://github.com/nab138/isideload, main branch snapshot retrieved 2026-10-24. Package version 0.5.0. Dependency versions are recorded in the top-level Cargo.lock.

License: MIT, see LICENSE-isideload.

Local change: `DeveloperSession::session_credentials` exposes a copy of the existing app token and account identifier to the DirectSide core. DirectSide stores them in the operating-system credential store so an existing developer session can be restored. No password is exported or stored. The export is not printed, included in error messages or passed to the Swift/JSON event bridge.

Local Windows authentication: `anisette/local/windows.rs` implements the CoreADI dispatcher ABI using the locally installed Apple runtime, with in-process initialization, OTP generation, provisioning and synchronization through Apple's own HTTPS endpoints. The native library is shared across provider instances. Device identity is derived locally and never emitted through the event protocol. The account builder requires an explicit provider and never silently chooses a remote server. The non-Windows local provider fails explicitly until a native implementation exists.

Windows dependencies added: `md-5` and scoped `windows-sys` APIs for the Apple-compatible machine identity and native library loading. ABI/protocol reference: https://github.com/Dadoum/apple-crates/tree/main/library-coreadi . No remote Anisette service is required by the DirectSide Windows core.

LiveContainer transfer: `Sideloader::livecontainer_certificate` returns an encrypted PKCS#12 archive using the existing signing identity for the selected developer team. The DirectSide core transfers this directly over USB, never through UI status events or logs. This is an explicit optional transfer and does not enable an embedded LiveContainer runtime.
