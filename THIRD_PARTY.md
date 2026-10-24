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

The Windows local authentication helper uses a subset of [os-findmy-e](https://github.com/sacca97/os-findmy-e), revision `374d83854f657a7fdca45f813387d99d491db0e2`, under MIT. Its unchanged license and DirectSide changes are in `vendor/mac-adi-python/`. Account authentication stays in the Rust engine; this helper runs Apple's Mac CoreADI under Unicorn without a network listener or remote Anisette service.

Unicorn 2.1.4 is included in the Windows package. The Python bindings are BSD-licensed; the emulator core is GPL v2. The full core license is in `licenses/Unicorn-GPL-2.0.txt`, and its corresponding source is the [2.1.4 tag](https://github.com/unicorn-engine/unicorn/tree/2.1.4). A public binary release must include the corresponding source and license material for its components. The Apple Mac runtime is proprietary and remains excluded from Git; its official download and exact hashes are in `scripts/prepare-mac-runtime.py`.

The local PyInstaller bootloader is rebuilt from verified 6.22.3 source using the project's documented `--no-cfg` option for Unicorn compatibility. No Windows system policy is changed. Source preparation and compiler commands are in `scripts/prepare-windows-bootloader.py`; the installed PyInstaller package is left intact.

The Windows application uses PySide6/Qt and PyInstaller. Version pins and packaging configuration are in `ui/requirements.txt` and `packaging/DirectSide.spec`.
