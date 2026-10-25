# Security

## Report a vulnerability

Use [private vulnerability reporting](https://github.com/Serekay/directside/security/advisories/new) for security issues. Do not post passwords, tokens, pairing records, signing keys, device identifiers or unredacted logs in public issues.

Only the latest release receives security fixes. A successful build is not a security certification.

## Official downloads

Download DirectSide from [this repository's releases](https://github.com/Serekay/directside/releases). The Windows app verifies GitHub asset sizes, SHA-256 digests and the IPA's main bundle identifier. This detects corrupt downloads; it does not protect against a compromised maintainer account or a malicious release published by that account.

The IPA is built without a personal Apple signing identity. Your Apple sign-in, pairing files and signing keys stay on your own computer/device and must never be uploaded to GitHub. HTTP app sources are supported for local development; use HTTPS on networks you do not trust.

## Repository safeguards

- iPhone builds are manually dispatched from the trusted default branch on temporary GitHub-hosted runners. Pull requests and forks cannot trigger our build.
- Build tokens have read-only repository access. Checkout credentials are not persisted. No release publishing credentials or Apple credentials are configured in Actions.
- Third-party Actions are pinned to complete commit hashes and restricted by repository policy.
- Secret scanning, push protection and dependency alerts supplement local commit checks. Dependabot proposes changes; updates are reviewed and never merged automatically.
- Default-branch and release-tag rules protect against accidental deletion or replacement. Repository administration can still change these settings.
- Future releases use GitHub release immutability. Existing releases are not retroactively locked.

See the [dated security review](docs/SECURITY-AUDIT.md) for scan coverage, validation and the remaining upstream RSA advisory.

Maintain two-factor authentication or passkeys on the owner account, review GitHub applications and tokens regularly, and never run unreviewed contributor code with local credentials present.
