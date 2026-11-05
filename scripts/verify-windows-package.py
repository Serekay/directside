"""Reject personal state in the distributable; never print matched contents."""
import argparse
import hashlib
import json
import marshal
from pathlib import Path, PurePosixPath
import types

from PyInstaller.archive.readers import CArchiveReader


def check_name(name):
    path = PurePosixPath(name.replace('\\', '/'))
    base = path.name.lower()
    if path.is_absolute() or '..' in path.parts or ':' in str(path):
        raise ValueError('Unsafe package path.')
    if (path.suffix.lower() in ('.p12', '.pfx', '.key', '.pem', '.p8', '.dpapi',
                               '.mobileprovision', '.mobiledevicepairing', '.sqlite', '.sqlite3', '.log')
            or base in ('preferences.json', 'pending-setup.json', '.env')
            or base.startswith('.env.')
            or any(word in base for word in ('session', 'credential', 'pairing', 'bootstrap', 'signing', 'imported'))
            and path.suffix.lower() in ('.json', '.plist')):
        raise ValueError('Personal runtime state is forbidden in the package.')


def strings(code):
    for value in code.co_consts:
        if isinstance(value, types.CodeType):
            yield from strings(value)
        elif isinstance(value, str):
            yield value.encode('utf-8')
        elif isinstance(value, bytes):
            yield value


def verify(path, private_markers=(), strings_directory=None):
    archive = CArchiveReader(str(path))
    markers = [encoded for value in private_markers if value and len(value) >= 8
               for encoded in (value.encode('utf-8'), value.encode('utf-16le'))]
    count = 0
    def inspect(data):
        if any(marker in data for marker in markers):
            raise ValueError('Personal account data detected; publication blocked.')
    output = Path(strings_directory) if strings_directory else None
    if output:
        output.mkdir(parents=True, exist_ok=True)
    inspect(Path(path).read_bytes())
    for name, entry in archive.toc.items():
        check_name(name)
        data = archive.extract(name)
        if data is not None:
            inspect(data)
        count += 1
        if entry[-1] in ('s', 'm'):
            content = b'\n'.join(strings(marshal.loads(data)))
            inspect(content)
            if output:
                (output / (hashlib.sha256(name.encode()).hexdigest() + '.txt')).write_bytes(content)
        elif entry[-1] == 'z':
            pyz = archive.open_embedded_archive(name)
            for module in pyz.toc:
                code = pyz.extract(module)
                if isinstance(code, types.CodeType):
                    content = b'\n'.join(strings(code))
                    inspect(content)
                    if output:
                        (output / (hashlib.sha256(module.encode()).hexdigest() + '.txt')).write_bytes(content)
    return {'passed': True, 'entries_checked': count,
            'private_markers_checked': len(markers) // 2,
            'sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('exe', type=Path)
    parser.add_argument('--preferences', type=Path)
    parser.add_argument('--strings-directory', type=Path)
    args = parser.parse_args()
    markers = []
    if args.preferences and args.preferences.is_file():
        email = json.loads(args.preferences.read_text(encoding='utf-8')).get('email')
        if isinstance(email, str):
            markers.append(email)
    try:
        print(json.dumps(verify(args.exe, markers, args.strings_directory)))
    except Exception:
        raise SystemExit('Windows package privacy verification failed; publication blocked. No private details logged.')
