# Third-party components

## iOS local authentication

The iPhone build uses the MIT `native/adi-core` subset of
[os-findmy-e](https://github.com/sacca97/os-findmy-e), revision
`374d83854f657a7fdca45f813387d99d491db0e2`, vendored in `vendor/mac-adi-rust/`.
It calls Apple's genuine Mac CoreADI under a local x86-64 guest interpreter.
No upstream Find My account code or plaintext account-storage tools are included.

The interpreter is built from [mahee96/unicorn](https://github.com/mahee96/unicorn),
revision `a53ddc9ac6d65b24936d4a37917333fcd816cfd0`, under GPL v2 with
LGPL components. The pinned source, compiler configuration and DirectSide's
read/write-only TCI allocation patch are recorded in `scripts/build-ios-mac-auth.py`.
The build does not use JIT, an installed SideStore app or a remote Anisette service.
See `licenses/Unicorn-GPL-2.0.txt` and the upstream source notices.
Corresponding source and license material must accompany a binary distribution.

AnisetteKit and its Android Apple Music libraries were used by the earlier IPA;
they are no longer linked or bundled by the current iPhone build. Their historical
notice remains available in Git history and `licenses/AnisetteKit-AGPL-3.0.txt`.

The Apple Mac CoreADI runtime is extracted from Apple's official iTunes package,
verified by SHA-256 and bundled as a resource. It is proprietary and excluded from
Git. Its download and hashes are in `scripts/prepare-mac-runtime.py`.

## isideload and idevice

The Rust signing and transport core uses isideload and idevice. See [vendor/README-DirectSide.md](vendor/README-DirectSide.md) and [vendor/LICENSE-isideload](vendor/LICENSE-isideload) for the vendored source and changes.

## Windows interface

The Windows local authentication helper uses a subset of [os-findmy-e](https://github.com/sacca97/os-findmy-e), revision `374d83854f657a7fdca45f813387d99d491db0e2`, under MIT. Its unchanged license and DirectSide changes are in `vendor/mac-adi-python/`. Account authentication stays in the Rust engine; this helper runs Apple's Mac CoreADI under Unicorn without a network listener or remote Anisette service.

Unicorn 2.1.4 is included in the Windows package. The Python bindings are BSD-licensed; the emulator core is GPL v2. The full core license is in `licenses/Unicorn-GPL-2.0.txt`, and its corresponding source is the [2.1.4 tag](https://github.com/unicorn-engine/unicorn/tree/2.1.4). A public binary release must include the corresponding source and license material for its components. The Apple Mac runtime is proprietary and remains excluded from Git; its official download and exact hashes are in `scripts/prepare-mac-runtime.py`.

The local PyInstaller bootloader is rebuilt from verified 6.22.3 source using the project's documented `--no-cfg` option for Unicorn compatibility. No Windows system policy is changed. Source preparation and compiler commands are in `scripts/prepare-windows-bootloader.py`; the installed PyInstaller package is left intact.

The Windows application uses PySide6/Qt and PyInstaller. Version pins and packaging configuration are in `ui/requirements.txt` and `packaging/DirectSide.spec`.
