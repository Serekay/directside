"""Check both committed Rust lockfiles against OSV before a manual iPhone build."""
import json
import subprocess
import tomllib
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def pin_utils_is_unshipped():
    """Do not exempt this web-only dependency if it enters either shipped target."""
    for target in ('x86_64-pc-windows-gnullvm', 'aarch64-apple-ios'):
        result = subprocess.run(['cargo', 'tree', '--locked', '--target', target,
                                 '--invert', 'pin-utils'], cwd=ROOT,
                                capture_output=True, text=True, timeout=120)
        if result.returncode != 0 or result.stdout.strip():
            return False
    return True


def audit():
    packages = set()
    for filename in ('Cargo.lock', 'vendor/mac-adi-rust/Cargo.lock'):
        for package in tomllib.loads((ROOT / filename).read_text(encoding='utf-8'))['package']:
            if package.get('source', '').startswith('registry+'):
                packages.add((package['name'], package['version']))
    items = sorted(packages)
    blocking = []
    for start in range(0, len(items), 100):
        batch = items[start:start + 100]
        query = {'queries': [{'package': {'name': name, 'ecosystem': 'crates.io'},
                              'version': version} for name, version in batch]}
        request = urllib.request.Request('https://api.osv.dev/v1/querybatch',
                                         data=json.dumps(query).encode(),
                                         headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read(4 * 1024 * 1024 + 1)
        if len(raw) > 4 * 1024 * 1024:
            raise RuntimeError('Dependency advisory response is too large.')
        results = json.loads(raw)['results']
        if len(results) != len(batch):
            raise RuntimeError('Incomplete dependency advisory response.')
        for (name, version), result in zip(batch, results):
            for advisory in result.get('vulns', []):
                identifier = advisory['id']
                # Narrow, visible contextual exception: no upstream patch exists.
                # Do not extend to other versions/advisories without a new review.
                if (name, version, identifier) == ('rsa', '0.9.10', 'RUSTSEC-2023-0071'):
                    print('WARNING: rsa 0.9.10 / RUSTSEC-2023-0071 remains present. '
                          'Used for local signing; no patched upstream version. '
                          'See SECURITY.md. This is not a constant-time fix.')
                elif (name, version, identifier) == ('pin-utils', '0.1.1', 'RUSTSEC-2026-0441') and pin_utils_is_unshipped():
                    print('WARNING: pin-utils 0.1.1 / RUSTSEC-2026-0441 is unmaintained. '
                          'Cargo verified it is absent from both Windows and iPhone target graphs; '
                          'it is only a transitive WebAssembly timer dependency. '
                          'This exception blocks if it enters either shipped target.')
                else:
                    blocking.append((name, version, identifier))
    for name, version, identifier in blocking:
        print(f'BLOCKED: {name} {version}: {identifier}')
    print(f'Checked {len(items)} registry package/version pairs; {len(blocking)} blocking advisories.')
    return 1 if blocking else 0


if __name__ == '__main__':
    raise SystemExit(audit())
