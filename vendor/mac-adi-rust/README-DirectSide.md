# Local Mac CoreADI adapter

MIT sources from sacca97/os-findmy-e, revision
374d83854f657a7fdca45f813387d99d491db0e2, native/adi-core.
Only the virtual Mac environment, CoreADI dispatcher and C ABI are included.
No Find My account code, passwords or upstream account-storage tools are used.

DirectSide changes: static library, pinned Unicorn TCI bindings, OS-backed
randomness and a bounded emulation call. Apple runtime bytes are checked against
the existing Windows runtime checksum. The iPhone build requires the separately
built x86-64 guest TCI interpreter, not a normal Unicorn JIT library.
