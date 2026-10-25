"""No GitHub writes: fixtures exercise corrupt downloads, private access and rollback."""
import hashlib
import io
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from urllib.request import Request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ui'))
from updates import API, ReleaseClient, GitHubRedirects, UpdateError, version, replace_application, digest


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.client = ReleaseClient(self.root, self.root / 'cache')
        self.client.token = lambda: ''

    def tearDown(self):
        self.temp.cleanup()

    def release(self, payload, name='DirectSide.exe'):
        return {'tag_name': 'v1.2.0', 'assets': [{'id': 123, 'name': name,
            'state': 'uploaded', 'digest': 'sha256:' + hashlib.sha256(payload).hexdigest(), 'size': len(payload)}]}

    def test_numeric_version_and_no_unreleased_builds(self):
        self.assertGreater(version('v1.10.0'), version('1.9.9'))
        for bad in ('1.2', 'v1.2.0-rc1', '../v1.2.0', 'latest'):
            with self.assertRaises(UpdateError): version(bad)
        for flag in ('draft', 'prerelease'):
            self.client.open = lambda _: io.BytesIO(json.dumps({'tag_name':'v1.0.0', flag:True}).encode())
            with self.assertRaises(UpdateError): self.client.latest()

    def test_empty_release_and_private_access_are_distinct(self):
        missing = HTTPError(API, 404, 'Not found', {}, None)
        self.client.open = Mock(side_effect=[missing, io.BytesIO(b'{}')])
        self.assertIsNone(self.client.latest())
        self.client.open = Mock(side_effect=[missing, missing])
        with self.assertRaisesRegex(UpdateError, 'vorübergehend nicht verfügbar'): self.client.latest()

    def test_token_not_forwarded_to_cdn_and_external_redirect_blocked(self):
        request = Request(API + '/releases/assets/123', headers={'Authorization':'Bearer fake-secret'})
        redirect = GitHubRedirects()
        redirected = redirect.redirect_request(request, None, 302, '', {}, 'https://release-assets.githubusercontent.com/asset')
        self.assertIsNone(redirected.get_header('Authorization'))
        for url in ('http://api.github.com/file', 'https://evil.example/file', 'https://api.github.com:444/file'):
            with self.assertRaises(UpdateError): redirect.redirect_request(request, None, 302, '', {}, url)

    def test_verified_download_cache_and_corruption_cleanup(self):
        payload = b'MZtest application'
        release = self.release(payload)
        self.client.open = Mock(return_value=io.BytesIO(payload))
        path = self.client.download(release, 'DirectSide.exe')
        self.assertEqual(path.read_bytes(), payload)
        self.client.download(release, 'DirectSide.exe')
        self.assertEqual(self.client.open.call_count, 1)
        path.unlink()
        for corrupt in (b'MZwrong', payload+b'extra'):
            self.client.open = Mock(return_value=io.BytesIO(corrupt))
            with self.assertRaises(UpdateError): self.client.download(release, 'DirectSide.exe')
            self.assertFalse(path.exists())
            self.assertEqual(list(self.client.cache.rglob('*.download')), [])
        release['assets'][0]['digest'] = None
        with self.assertRaises(UpdateError): self.client.download(release, 'DirectSide.exe')

    def test_other_app_cannot_be_installed_as_directside(self):
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w') as archive:
            archive.writestr('Payload/Other.app/Info.plist', plistlib.dumps({'CFBundleIdentifier':'other.app'}))
        payload = stream.getvalue()
        self.client.open = lambda *a, **kw: io.BytesIO(payload)
        with self.assertRaisesRegex(UpdateError, 'keine DirectSide'):
            self.client.download(self.release(payload,'DirectSide.ipa'),'DirectSide.ipa')

    def test_atomic_replace_retains_backup_and_rolls_back_launch_failure(self):
        source = self.root / 'new.exe'; source.write_bytes(b'MZnew')
        target = self.root / 'DirectSide.exe'; target.write_bytes(b'MZold')
        launched = []
        replace_application(source, target, digest(source), launched.append)
        self.assertEqual(target.read_bytes(), b'MZnew')
        self.assertEqual(target.with_name('DirectSide.previous.exe').read_bytes(), b'MZold')
        self.assertEqual(launched, [target])
        source.write_bytes(b'MZnewer')
        with self.assertRaises(OSError):
            replace_application(source, target, digest(source), Mock(side_effect=OSError('cannot start')))
        self.assertEqual(target.read_bytes(), b'MZnew')
        with self.assertRaises(UpdateError): replace_application(source, target, '0'*64, launched.append)
        self.assertEqual(target.read_bytes(), b'MZnew')

    def test_locked_application_is_not_removed(self):
        source = self.root/'new.exe'; source.write_bytes(b'MZnew')
        target = self.root/'DirectSide.exe'; target.write_bytes(b'MZold')
        with patch('updates.os.replace', side_effect=PermissionError('locked')):
            with self.assertRaises(PermissionError): replace_application(source, target, digest(source), Mock())
        self.assertEqual(target.read_bytes(), b'MZold')
        self.assertFalse(target.with_name('DirectSide.update.exe').exists())

    def test_private_token_is_dpapi_encrypted(self):
        from local_mac_auth import protect
        token = 'github_pat_' + 'A'*40
        self.client.save_token(token)
        data = (self.client.cache/'github.dpapi').read_bytes()
        self.assertNotIn(token.encode(), data)
        self.assertEqual(protect(data, decrypt=True).decode(), token)
        self.client.forget_token()
        self.assertFalse((self.client.cache/'github.dpapi').exists())


if __name__ == '__main__': unittest.main()
