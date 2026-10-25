# Repository security review - 25 October 2026

Scope: the public `Serekay/directside` repository, reachable Git history, GitHub access settings, Actions workflow and logs, published release assets, and declared Python/Rust dependencies. This is a recorded review, not a guarantee that the application has no vulnerabilities.

## Access and publication

- Serekay is the sole repository collaborator (administrator). No outstanding collaborator invitations, deploy keys, webhooks, deployment environments, self-hosted runners, Actions secrets or Actions variables were present.
- Default-branch updates and version-tag creation require repository administration. Separate rules block deletion and force pushes on the default branch, and modification/deletion of existing version tags, without an administrator bypass for those history rules.
- Release immutability is enabled for **future releases**. GitHub does not retroactively lock the assets of releases 0.1.0 and 0.1.1. Those files were downloaded and their sizes and SHA-256 digests verified during this review.
- Private vulnerability reporting, GitHub secret scanning, provider push protection, Dependabot alerts and proposed security updates are enabled. No automatic merging is configured.
- Owner-account two-factor authentication could not be verified through the current API access. Account recovery methods, OAuth grants, personal tokens, and the security of the owner's computer remain outside this repository review.

## Build hardening

- Manual dispatch only, with an explicit official-repository/default-branch guard. No pull-request, issue, comment or fork trigger.
- Read-only build token; no persisted checkout credentials. Temporary GitHub-hosted macOS runner, a 45-minute limit and one build concurrency group.
- Checkout, cache and artifact-upload Actions use verified full commit hashes. Repository policy requires full SHA pins and allows only those three pinned Actions.
- Compiled authentication libraries are no longer restored from the Actions cache. Registry/git dependency caches are retained; Cargo builds use committed lockfiles.
- Before compilation, a pinned, SHA-256-verified Gitleaks binary checks the complete checkout history. Its raw findings are captured and withheld from public logs on failure.
- Before compilation, both Rust lockfiles are checked against OSV. New advisories stop the build; the exact RSA version/advisory discussed below remains explicitly reported as a contextual warning.
- The unsigned IPA publication check rejects embedded personal signing/pairing material and unsafe archive paths. Only the explicit IPA file is uploaded, with seven-day artifact retention.
- Weekly dependency update proposals cover Actions, both Rust lockfiles and Python requirements. Proposals require review; the SHA allowlist must be updated deliberately when accepting new Action pins.

## Scan results

- Gitleaks 8.30.1: **81 reachable commits**, zero findings. Remote branches and tags were fetched and checked.
- Available historical Actions logs: **74 files**, zero findings. One Dependabot-generated dynamic run had no downloadable log archive; it was not an iPhone build.
- Published 0.1.0 and 0.1.1: all **6 release assets** downloaded and hash-verified, zero Gitleaks findings. Both unsigned IPAs passed the stricter publication gate and contained no personal signing/provisioning/pairing files.
- Application-code string constants were also read from the compressed Python archives of both published EXEs: **11 modules**, zero secret-scan findings. No bundled credential files were found in their archive inventories.
- Python requirements and resolved dependencies: **9 packages**, no known vulnerabilities reported by pip-audit.
- Rust lockfiles: **424 unique registry package/version pairs** checked against OSV after updates. One upstream advisory remains, described below.
- GitHub's secret-scanning and dependency-alert APIs returned no open alerts at the time of review. Alert indexing and scanner coverage are not proof that no secrets or defects exist.

## Dependency fixes and remaining advisory

The source and lockfile now use patched Rustls, WebPKI/root stores, Tokio, crypto-bigint, ctutils and ZIP dependencies. ZIP moved from 8.6.0 to 9.1.1; the IPA inspector handles its fallible filename API. Regression tests cover normal IPA inspection and rejection of symlinks that escape the extraction directory.

**RUSTSEC-2023-0071 (`rsa` 0.9.10) remains reported.** Upstream reports no patched version. It concerns private-key timing leakage where an attacker can observe repeated RSA operations, especially over a network. DirectSide's usage is local key generation/import and certificate/code signing; it does not implement an RSA-decryption service. Upstream explicitly distinguishes ordinary local use on an uncompromised machine. The build audit has a visible warning for this exact package/version/advisory; other findings block the build. This contextual assessment is not a constant-time implementation fix. See the [RustSec advisory](https://rustsec.org/advisories/RUSTSEC-2023-0071.html).

These dependency fixes are **not present in the already published 0.1.0/0.1.1 binaries**. This review does not replace release assets or publish a new version. A new IPA build and release require the owner's release instruction.

## Validation and boundaries

The hardened workflow passes Actionlint. Local tests pass: **90 Python/UI tests, 12 core Rust tests and 9 vendor Rust tests**, including the new archive/publication checks and fail-closed dependency/scanner gates. Public-log redaction on secret-scan failure is also covered. The shared Rust code compiles on Windows. No new macOS/iPhone Actions build was dispatched during this review, and Apple login or installation was not repeated with personal credentials.

A fresh Windows EXE was built locally under the ignored `build/security-hardened/` directory. Its packaged Qt/QML, icon, signing-engine and local authentication-runtime startup checks passed. The canonical `dist/` files and public release assets were not replaced.

GitHub-hosted runner images, SDKs, Homebrew tools and upstream package infrastructure remain external trust dependencies. HTTP app sources remain intentionally supported and do not authenticate or encrypt traffic; use HTTPS outside trusted local development networks. A compromised owner account or computer remains a material risk.

No secret values or raw diagnostic dumps are included in this report. Detailed scan files and downloaded verification copies remain under the ignored local `build/security-audit-2026-10-25/` directory.
