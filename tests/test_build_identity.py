import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

spec = importlib.util.spec_from_file_location('verify_ipa', Path(__file__).resolve().parents[1] / 'scripts/verify-directside-ipa.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class BuildIdentityTests(unittest.TestCase):
    def test_build_number_changes_keep_identity_and_signed_artifacts_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'DirectSide.ipa'
            for identifier, build in [('com.directside.app', '6'), ('com.directside.app', '7'),
                                      ('com.directside.app.TESTTEAM01', '7'), ('com.directside.app.build7', '7')]:
                with ZipFile(path, 'w') as archive:
                    archive.writestr('Payload/DirectSide.app/Info.plist', plistlib.dumps({
                        'CFBundleIdentifier': identifier, 'CFBundleVersion': build}))
                if identifier == 'com.directside.app':
                    self.assertEqual(verifier.verify(path)['CFBundleVersion'], build)
                else:
                    with self.assertRaises(ValueError):
                        verifier.verify(path)
