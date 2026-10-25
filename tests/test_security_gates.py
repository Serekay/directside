"""Exercise fail-closed build checks without exposing findings in public logs."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit = load('dependency_audit', 'audit-rust-dependencies.py')
scanner = load('build_secret_scan', 'scan-build-secrets.py')


class SecurityGateTests(unittest.TestCase):
    def test_an_advisory_other_than_the_exact_reviewed_rsa_warning_blocks(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'vendor/mac-adi-rust').mkdir(parents=True)
            lock = '[[package]]\nname="rsa"\nversion="0.9.10"\nsource="registry+https://github.com/rust-lang/crates.io-index"\n'
            for name in ('Cargo.lock', 'vendor/mac-adi-rust/Cargo.lock'):
                (root / name).write_text(lock, encoding='utf-8')
            for advisories, expected in [(['RUSTSEC-2023-0071'], 0),
                                         (['RUSTSEC-2023-0071', 'RUSTSEC-2099-0001'], 1)]:
                response = io.BytesIO(json.dumps({'results': [{'vulns': [{'id': a} for a in advisories]}]}).encode())
                with self.subTest(advisories=advisories), patch.object(audit, 'ROOT', root), patch.object(audit.urllib.request, 'urlopen', return_value=response), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(audit.audit(), expected)

    def test_incomplete_advisory_results_do_not_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'vendor/mac-adi-rust').mkdir(parents=True)
            lock = '[[package]]\nname="example"\nversion="1.0.0"\nsource="registry+https://github.com/rust-lang/crates.io-index"\n'
            for name in ('Cargo.lock', 'vendor/mac-adi-rust/Cargo.lock'):
                (root / name).write_text(lock, encoding='utf-8')
            with patch.object(audit, 'ROOT', root), patch.object(audit.urllib.request, 'urlopen', return_value=io.BytesIO(b'{"results":[]}')):
                with self.assertRaises(RuntimeError):
                    audit.audit()

    def test_unverified_scanner_is_never_executed(self):
        with patch.object(scanner.platform, 'system', return_value='Darwin'), patch.object(scanner.platform, 'machine', return_value='arm64'), patch.object(scanner.urllib.request, 'urlopen', return_value=io.BytesIO(b'tampered download')), patch.object(scanner.subprocess, 'run') as run:
            with self.assertRaises(RuntimeError):
                scanner.main()
            run.assert_not_called()

    def test_failed_secret_scan_withholds_sensitive_subprocess_output(self):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w:gz') as package:
            entry = tarfile.TarInfo('gitleaks')
            entry.size = 4
            package.addfile(entry, io.BytesIO(b'test'))
        data = archive.getvalue()
        output = io.StringIO()
        with patch.object(scanner.platform, 'system', return_value='Darwin'), patch.object(scanner.platform, 'machine', return_value='arm64'), patch.object(scanner.urllib.request, 'urlopen', return_value=io.BytesIO(data)), patch.object(scanner, 'CHECKSUMS', {'arm64': hashlib.sha256(data).hexdigest()}), patch.object(scanner.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, stdout=b'PRIVATE-FINDING', stderr=b'PRIVATE-FINDING')), contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            with self.assertRaises(RuntimeError) as error:
                scanner.main()
        self.assertNotIn('PRIVATE-FINDING', output.getvalue() + str(error.exception))
