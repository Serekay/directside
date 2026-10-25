"""Offline checks: no Apple accounts or network calls."""
import sys
import unittest
import base64
import struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
from local_mac_auth import apple_url,protect,export_identity

class LocalMacAuthenticationTests(unittest.TestCase):
    def test_usb_identity_export_uses_the_interpreter_store_format(self):
        saved={'identity':{'host_uuid':'01'*16,'device_id':'fixture-device','local_user_uuid':'A'*32,'serial':'fixture-serial'},'store':{'adi.pb':base64.b64encode(b'ignored').decode(),'adi-FFFFFFFF.pb':base64.b64encode(b'fixture-store').decode()}}
        exported=export_identity(saved)
        self.assertEqual(base64.b64decode(exported['host']),bytes([1])*16)
        store=base64.b64decode(exported['store']);name_length=struct.unpack('>H',store[:2])[0]
        self.assertEqual(store[2:2+name_length],b'adi-FFFFFFFF.pb')
        data_length=struct.unpack('>I',store[2+name_length:6+name_length])[0]
        self.assertEqual(store[6+name_length:],b'fixture-store');self.assertEqual(data_length,13)
        saved['store']['../outside']='AA=='
        with self.assertRaises(ValueError):export_identity(saved)
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
