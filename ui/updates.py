"""GitHub release discovery, verified downloads and a separate-process Windows updater.

Only published stable releases are installable. Never ships a repository credential.
"""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, HTTPRedirectHandler, build_opener

VERSION = '0.1.2'
BUILD = 17
REPOSITORY = 'Serekay/directside'
API = 'https://api.github.com/repos/' + REPOSITORY
CACHE = Path(os.environ.get('LOCALAPPDATA', Path.home())) / 'DirectSide' / 'updates'


class UpdateError(Exception):
    pass


def version(value):
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)', value)
    if not match:
        raise UpdateError('Ungültige Release-Version.')
    return tuple(map(int, match.groups()))


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


class GitHubRedirects(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        parsed = urlsplit(new_url)
        if parsed.scheme != 'https' or parsed.hostname not in (
                'api.github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com') or parsed.username or parsed.password or parsed.port not in (None, 443):
            raise UpdateError('Unerwarteter GitHub-Downloadserver.')
        redirected = super().redirect_request(request, fp, code, message, headers, new_url)
        # urllib otherwise forwards Authorization to GitHub's signed CDN URL.
        if parsed.hostname != 'api.github.com':
            redirected.remove_header('Authorization')
        return redirected


class ReleaseClient:
    def __init__(self, root, cache=None):
        self.root = Path(root)
        # Local builds can live in dist/ or build/<staging-name>/.
        for candidate in (self.root, *list(self.root.parents)[:2]):
            if (candidate / '.tools/github-cli/bin/gh.exe').is_file():
                self.root = candidate
                break
        self.cache = Path(cache) if cache else CACHE
        self.opener = build_opener(GitHubRedirects())

    def save_token(self, token):
        from local_mac_auth import protect
        if not re.fullmatch(r'[A-Za-z0-9_]{20,255}', token):
            raise UpdateError('Ungültiger GitHub-Zugang.')
        self.cache.mkdir(parents=True, exist_ok=True)
        path = self.cache / 'github.dpapi'
        temporary = path.with_suffix('.tmp')
        temporary.write_bytes(protect(token.encode()))
        temporary.replace(path)

    def forget_token(self):
        (self.cache / 'github.dpapi').unlink(missing_ok=True)

    def token(self):
        path = self.cache / 'github.dpapi'
        if path.exists():
            from local_mac_auth import protect
            try:
                return protect(path.read_bytes(), decrypt=True).decode()
            except (OSError, ValueError):
                raise UpdateError('Gespeicherten GitHub-Zugang erneut einrichten.') from None
        # Reuse this developer PC's existing login; gh is neither bundled nor required.
        cli = self.root / '.tools/github-cli/bin/gh.exe'
        if cli.is_file():
            result = subprocess.run([str(cli), 'auth', 'token', '--hostname', 'github.com'],
                capture_output=True, timeout=10, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            if result.returncode == 0:
                return result.stdout.decode().strip()
        return ''

    def open(self, url, binary=False):
        if url != API and not url.startswith(API + '/'):
            raise UpdateError('Unerwartete GitHub-Adresse.')
        headers = {'User-Agent': 'DirectSide/' + VERSION,
            'Accept': 'application/octet-stream' if binary else 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28'}
        token = self.token()
        if token:
            headers['Authorization'] = 'Bearer ' + token
        return self.opener.open(Request(url, headers=headers), timeout=30)

    def latest(self):
        try:
            with self.open(API + '/releases/latest') as response:
                raw = response.read(1_000_001)
        except HTTPError as error:
            if error.code == 404:
                # Distinguish a private/inaccessible repository from an empty release list.
                try:
                    with self.open(API) as response:
                        response.read(1)
                except HTTPError:
                    raise UpdateError('Updateprüfung vorübergehend nicht verfügbar. Bitte später erneut versuchen.') from None
                return None
            if error.code in (401, 403):
                raise UpdateError('Updateprüfung vorübergehend nicht verfügbar. Bitte später erneut versuchen.') from None
            raise UpdateError('GitHub momentan nicht erreichbar.') from None
        if len(raw) > 1_000_000:
            raise UpdateError('Ungültige Release-Metadaten.')
        release = json.loads(raw)
        version(release.get('tag_name', ''))
        if release.get('draft') or release.get('prerelease'):
            raise UpdateError('Diese Version ist noch nicht freigegeben.')
        return release

    def asset(self, release, name):
        matches = [a for a in release.get('assets', []) if a.get('name') == name and a.get('state') == 'uploaded']
        if len(matches) != 1:
            raise UpdateError('Datei fehlt im GitHub-Release: ' + name)
        asset = matches[0]
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', asset.get('digest') or ''):
            raise UpdateError('GitHub-Prüfsumme fehlt: ' + name)
        if not isinstance(asset.get('id'), int) or asset['id'] <= 0 or not 0 < asset.get('size', 0) <= 500_000_000:
            raise UpdateError('Ungültige Release-Datei.')
        return asset

    def download(self, release, name, progress=lambda _: None):
        asset = self.asset(release, name)
        expected = asset['digest'].split(':')[1]
        folder = self.cache / release['tag_name'] / expected
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / name
        if target.is_file() and target.stat().st_size == asset['size'] and digest(target) == expected:
            return target
        partial = target.with_suffix('.download')
        try:
            with self.open(API + '/releases/assets/' + str(asset['id']), binary=True) as source, partial.open('wb') as output:
                done = 0
                while block := source.read(1024 * 1024):
                    done += len(block)
                    if done > asset['size']:
                        raise UpdateError('GitHub-Download ist größer als angekündigt.')
                    output.write(block)
                    progress(int(done / asset['size'] * 100))
            if done != asset['size'] or digest(partial) != expected:
                raise UpdateError('GitHub-Download ist unvollständig oder beschädigt.')
            if name == 'DirectSide.ipa':
                from common import ipa_identity
                if ipa_identity(partial) != 'com.directside.app':
                    raise UpdateError('Die IPA ist keine DirectSide-App.')
            else:
                with partial.open('rb') as executable:
                    if executable.read(2) != b'MZ':
                        raise UpdateError('Die Datei ist keine Windows-Anwendung.')
            partial.replace(target)
            return target
        finally:
            partial.unlink(missing_ok=True)


def replace_application(source, target, expected, launch):
    """Keep the old EXE on any replacement/restart failure. No credentials touched."""
    source, target = Path(source), Path(target)
    if target.name.lower() != 'directside.exe' or source.resolve() == target.resolve() or digest(source) != expected:
        raise UpdateError('Ungültiges Windows-Update.')
    incoming = target.with_name('DirectSide.update.exe')
    backup = target.with_name('DirectSide.previous.exe')
    shutil.copyfile(source, incoming)
    try:
        if digest(incoming) != expected:
            raise UpdateError('Windows-Update konnte nicht geprüft werden.')
        os.replace(target, backup)
        try:
            os.replace(incoming, target)
            launch(target)
        except Exception:
            os.replace(backup, target)
            raise
    finally:
        incoming.unlink(missing_ok=True)


def apply_update(arguments):
    """Entry point in the staged new EXE; wait for the parent before replacement."""
    report = CACHE / 'last-update.json'
    try:
        pid, target, expected = arguments
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x100000, False, int(pid))
        if handle:
            try:
                if kernel.WaitForSingleObject(handle, 120000) != 0:
                    raise UpdateError('DirectSide wurde nicht rechtzeitig geschlossen.')
            finally:
                kernel.CloseHandle(handle)
        elif ctypes.get_last_error() != 87:
            raise UpdateError('DirectSide-Prozess konnte nicht geprüft werden.')
        # PyInstaller's outer one-file process may still be cleaning up after Qt exits.
        for attempt in range(30):
            try:
                replace_application(sys.executable, target, expected,
                    lambda path: subprocess.Popen([str(path)], cwd=str(path.parent), close_fds=True))
                break
            except PermissionError:
                if attempt == 29:raise
                time.sleep(0.5)
        result = {'ok': True, 'version': VERSION}
    except Exception:
        result = {'ok': False, 'message': 'Windows-Update fehlgeschlagen. Vorherige Version bleibt erhalten.'}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result), encoding='utf-8')
    return 0 if result['ok'] else 1
