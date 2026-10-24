import sys
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
import components

class ComponentSetupTests(unittest.TestCase):
    def test_setup_download_cannot_redirect_to_foreign_or_insecure_host(self):
        self.assertTrue(components.apple_url(components.APPLE_SETUP_URL))
        for url in ['http://apple.com/file','https://apple.com.evil.example/file','https://user:secret@apple.com/file','https://example.com/file']:
            self.assertFalse(components.apple_url(url))

    def test_installer_hash_is_verified_before_use(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'setup.exe';path.write_bytes(b'verified fixture')
            expected=hashlib.sha256(b'verified fixture').hexdigest().upper()
            with patch.object(components,'APPLE_SETUP_SHA256',expected):
                self.assertTrue(components.verified_installer(path))
                path.write_bytes(b'tampered')
                self.assertFalse(components.verified_installer(path))

    def test_healthy_installation_is_not_changed(self):
        events=[]
        with patch.object(components,'usb_status',return_value='ready'),patch.object(components,'elevated') as launch:
            components.setup_apple(events.append);launch.assert_not_called()
        self.assertEqual(events[-1]['type'],'done')

    def test_stopped_service_uses_builtin_start_without_download(self):
        events=[]
        with patch.object(components,'usb_status',side_effect=['stopped','ready']),patch.object(components,'elevated',return_value=0) as launch:
            components.setup_apple(events.append)
        self.assertEqual(launch.call_count,1)
        self.assertEqual(Path(launch.call_args.args[0]).name,'sc.exe')
        self.assertEqual(events[-1]['type'],'done')

if __name__=='__main__':unittest.main()
