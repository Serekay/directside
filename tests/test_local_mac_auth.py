"""Offline checks: no Apple accounts or network calls."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
from local_mac_auth import apple_url,protect

class LocalMacAuthenticationTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform=='win32','Windows user protection')
    def test_identity_is_protected_for_the_current_windows_user(self):
        value=b'{"identity":"synthetic fixture","store":"fixture"}'
        encrypted=protect(value)
        self.assertNotIn(b'synthetic fixture',encrypted)
        self.assertEqual(protect(encrypted,True),value)
        damaged=bytearray(encrypted);damaged[-1]^=1
        with self.assertRaises(OSError):protect(bytes(damaged),True)

    def test_provisioning_accepts_only_apple_https_endpoints(self):
        self.assertEqual(apple_url('https://gsa.apple.com/provision'),'https://gsa.apple.com/provision')
        for value in ['http://gsa.apple.com/','https://apple.com.example.org/','https://example.org/','https://user:pass@gsa.apple.com/']:
            with self.assertRaises(ValueError):apple_url(value)
