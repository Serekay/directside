import sys
import unittest
import tempfile
import plistlib
from pathlib import Path
from zipfile import ZipFile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
from common import ipa_identity,clean_error,Preferences,valid_code

class BootstrapTests(unittest.TestCase):
    def test_only_main_app_determines_pairing_target(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'test.ipa'
            with ZipFile(path,'w') as z:
                z.writestr('Payload/DirectSide.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'com.directside.app'}))
                z.writestr('Payload/DirectSide.app/PlugIns/Other.appex/Info.plist',plistlib.dumps({'CFBundleIdentifier':'other'}))
            self.assertEqual(ipa_identity(path),'com.directside.app')

    def test_ambiguous_ipa_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'bad.ipa'
            with ZipFile(path,'w') as z:
                for name in ['One','Two']:
                    z.writestr(f'Payload/{name}.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':name}))
            with self.assertRaises(ValueError):ipa_identity(path)

    def test_error_display_redacts_email(self):
        self.assertNotIn('person@example.com',clean_error('Failure for person@example.com'))

    def test_account_preferences_survive_restart_without_password_storage(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'settings.json'
            Preferences(path).save(' person@example.com ')
            self.assertEqual(Preferences(path).load(),{'email':'person@example.com','language':'en','signing_mode':'account'})
            import json
            self.assertEqual(set(json.loads(path.read_text())),{'email','language','signing_mode'})
            path.write_text(json.dumps({'email':'person@example.com','server':'https://obsolete.example'}))
            self.assertEqual(Preferences(path).load(),{'email':'person@example.com','language':'en','signing_mode':'account'})
            path.write_text('{broken')
            self.assertEqual(Preferences(path).load(),{})

    def test_confirmation_code_requires_six_ascii_digits(self):
        self.assertTrue(valid_code('012345'))
        for value in ['12345','1234567','１２３４５６','12 345','abcdef']:
            self.assertFalse(valid_code(value))

if __name__=='__main__':unittest.main()
