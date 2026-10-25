"""Scan the full checkout history with a verified, pinned Gitleaks binary.

Only reports pass/fail; findings must never be echoed into public build logs.
"""
import hashlib
import io
import platform
import subprocess
import tarfile
import tempfile
import urllib.request
from pathlib import Path

VERSION = '8.30.1'
CHECKSUMS = {
    'arm64': 'b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5',
    'x64': 'dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709',
}


def main():
    if platform.system() != 'Darwin':
        raise RuntimeError('This CI secret scanner is for macOS. Use local Gitleaks on other systems.')
    machine = platform.machine()
    if machine not in ('arm64', 'aarch64', 'x86_64'):
        raise RuntimeError('Unsupported scanner architecture.')
    arch = 'arm64' if machine in ('arm64', 'aarch64') else 'x64'
    url = f'https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/gitleaks_{VERSION}_darwin_{arch}.tar.gz'
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read(32 * 1024 * 1024 + 1)
    if len(data) > 32 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != CHECKSUMS[arch]:
        raise RuntimeError('Secret scanner download failed checksum verification.')
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='directside-secret-check-') as folder:
        binary = Path(folder) / 'gitleaks'
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            member = archive.getmember('gitleaks')
            if not member.isfile() or member.size > 64 * 1024 * 1024:
                raise RuntimeError('Invalid secret scanner archive.')
            binary.write_bytes(archive.extractfile(member).read())
        binary.chmod(0o700)
        result = subprocess.run([str(binary), 'git', '--log-opts=--all', '--redact=100',
                                 '--ignore-gitleaks-allow', '--no-banner', str(root)],
                                cwd=root, capture_output=True, timeout=180)
        if result.returncode:
            raise RuntimeError('Secret scan failed. Inspect the repository locally; raw findings are withheld from public logs.')
    print('Full-history secret scan passed. No finding content logged.')


if __name__ == '__main__':
    main()
