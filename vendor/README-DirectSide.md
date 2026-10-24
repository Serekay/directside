# Vendored isideload

Source: https://github.com/nab138/isideload, main branch snapshot retrieved 2026-10-24. Package version 0.5.0. Dependency versions are recorded in the top-level Cargo.lock.

License: MIT, see LICENSE-isideload.

Local change: `DeveloperSession::session_credentials` exposes a copy of the existing app token and account identifier to the DirectSide core. DirectSide stores them in the operating-system credential store so an existing developer session can be restored. No password is exported or stored. The export is not printed, included in error messages or passed to the Swift/JSON event bridge.

Further changes must be documented here.
