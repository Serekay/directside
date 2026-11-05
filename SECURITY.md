# Security policy

## Reporting a vulnerability

Report security issues through [private vulnerability reporting](https://github.com/Serekay/directside/security/advisories/new). Include the affected version, steps to reproduce and expected impact.

Do not include passwords, tokens, pairing records, signing keys, device identifiers or unredacted logs in public issues. Only the latest stable release receives fixes.

## Account and signing data

DirectSide authenticates with Apple locally. Account sessions and signing identities are stored using the operating system's credential storage. Published IPAs are unsigned and contain no personal Apple identity or device pairing.

Download binaries from the [official releases](https://github.com/Serekay/directside/releases). App sources and imported IPAs are supplied by their publishers; only install apps and sources you trust. Prefer HTTPS sources outside a trusted local network.

## Known dependency limitation

The signing core currently uses `rsa` 0.9.10, which is affected by [RUSTSEC-2023-0071](https://rustsec.org/advisories/RUSTSEC-2023-0071.html). No patched upstream version is available. DirectSide uses RSA for local signing; this does not eliminate the dependency's timing limitation.
