# Local Mac ADI emulator subset

Source: https://github.com/sacca97/os-findmy-e
Pinned revision: `374d83854f657a7fdca45f813387d99d491db0e2`.
MIT license; copyright 2026 sacca. The included LICENSE is unchanged.

Only the Mach-O loader, CPU harness, operating-system stubs, CoreADI dispatcher,
local machine provisioning and its transport support are included. No Find My,
tag, account-password or keychain-recovery code is used.

DirectSide's adapter is `ui/local_mac_auth.py`. It uses Windows DPAPI to persist
the machine identity and provisioning store together, instead of the upstream
plaintext JSON/PB files. It verifies the runtime hash, uses the real clock,
checks TLS certificates and accepts only Apple HTTPS provisioning endpoints.
The two upstream lines disabling TLS checks have been removed from `gsa.py`.
The helper receives only an operation and optional Apple resync data over private
pipes; user credentials stay in the Rust engine. There is no listening service.

Apple's Mac CoreADI comes from its official iTunes 12.8.3 download, is pinned by
installer and library SHA-256, and is prepared at build time. It is not in Git.
Unicorn 2.1.4 runs the Apple code locally. The packaged application includes all
required runtime components; no separate emulator or iTunes installation is used.
