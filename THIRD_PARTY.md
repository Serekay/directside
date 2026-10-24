# Third-party components

## AnisetteKit — iOS authentication

- Upstream: https://github.com/mahee96/AnisetteKit
- Pinned revision: `db8b41022697b6c19be8a5f01a1ce834145a2a26`
- Copyright © 2026 Magesh K.
- License: GNU AGPL v3; the full notice is in [licenses/AnisetteKit-AGPL-3.0.txt](licenses/AnisetteKit-AGPL-3.0.txt).
- The iOS application links this library. Combined iOS builds are subject to its AGPL terms; recipients must receive corresponding source and notices. DirectSide's original code remains available under its MIT license. Private development does not require making this repository public.

AnisetteKit supplies the Unicorn TCI interpreter integration. Its Swift package pins the Unicorn XCFramework URL and checksum. There is no dependency on an installed SideStore app or an Anisette server.

The Apple ARM64 libraries are extracted from Apple's own Apple Music package during the build, verified by SHA-256 and bundled as runtime resources. They are proprietary Apple components, not covered by DirectSide's MIT license. They are not committed to this repository. The URL and hashes are recorded in `scripts/prepare-anisette-runtime.py` and the bundle's runtime provenance manifest. Public redistribution of Apple components requires a separate review before a public release.

## isideload and idevice

The Rust signing and transport core uses isideload and idevice. See [vendor/README-DirectSide.md](vendor/README-DirectSide.md) and [vendor/LICENSE-isideload](vendor/LICENSE-isideload) for the vendored source and changes.

## Windows interface

The Windows application uses PySide6/Qt and PyInstaller. Version pins and packaging configuration are in `ui/requirements.txt` and `packaging/DirectSide.spec`.
