# Vendored isideload

Source: [nab138/isideload](https://github.com/nab138/isideload), version 0.5.0, snapshot retrieved 2026-10-24. License: MIT; see [LICENSE-isideload](LICENSE-isideload). Dependency versions are recorded in the root `Cargo.lock`.

## DirectSide integration

- Explicit local authentication providers: the Windows Mac CoreADI helper and the iOS callback adapter. No automatic remote Anisette fallback.
- Session restoration through operating-system credential storage. Exported session context excludes passwords and is not included in UI events or logs.
- Separate GrandSlam and developer-service identities, with OTP expiration aligned to the generation window.
- Shared iPhone signing callbacks, bounded synchronization data and matching allocation/disposal callbacks.
- Stable application identifiers, imported signing identities and installation checks that preserve the selected application/team.
- Optional encrypted PKCS#12 export for local LiveContainer certificate setup, separate from UI status events.

The platform adapters use the sources documented in [mac-adi-python/README-DirectSide.md](mac-adi-python/README-DirectSide.md) and [mac-adi-rust/README-DirectSide.md](mac-adi-rust/README-DirectSide.md). Protocol references include [apple-crates](https://github.com/Dadoum/apple-crates/tree/main/library-coreadi) and [os-findmy-e](https://github.com/sacca97/os-findmy-e).
