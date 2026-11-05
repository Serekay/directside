import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import marshal

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('windows_package', ROOT / 'scripts/verify-windows-package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
sys.path.insert(0, str(ROOT / 'ui'))
from common import Preferences
from desktop import DesktopBridge


class WindowsPackageTests(unittest.TestCase):
    def test_private_value_inside_compressed_python_blocks_distribution(self):
        code = compile("def nested():\n return 'private-session-fixture'\n", '<fixture>', 'exec')
        class Archive:
            toc = {'desktop': (0, 1, 1, 1, 's')}
            def extract(self, name):
                return marshal.dumps(code)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'fixture.exe'
            path.write_bytes(b'compressed-container-fixture')
            with patch.object(package, 'CArchiveReader', return_value=Archive()):
                with self.assertRaisesRegex(ValueError, 'Personal account data detected'):
                    package.verify(path, ['private-session-fixture'])
                self.assertTrue(package.verify(path, ['unrelated-fixture'])['passed'])

    def test_personal_material_cannot_be_packaged(self):
        for name in ('preferences.json', 'DirectSide/session.json', 'identity.p12',
                     'vendor/mac-adi-python/account.dpapi', 'pending-setup.json',
                     'DirectSide-pairing.plist', 'DirectSide-signing.json',
                     'C:/Users/private.json', '../private.json'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.check_name(name)
        for name in ('en.json', 'assets/apple_root.cer', 'ui/Main.qml', 'bin/directside-engine.exe'):
            package.check_name(name)

    def test_fresh_user_has_no_account_or_authenticated_state(self):
        with tempfile.TemporaryDirectory() as folder:
            prefs = Preferences(Path(folder) / 'preferences.json')
            self.assertEqual(prefs.load(), {})
            bridge = DesktopBridge(start=False, preferences=prefs)
            try:
                self.assertEqual(bridge.data['email'], '')
                self.assertFalse(bridge.data['loggedIn'])
                self.assertFalse(bridge.data['canSign'])
                self.assertEqual(bridge.data['language'], 'en')
            finally:
                bridge.close()
