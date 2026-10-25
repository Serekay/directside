"""Reject a DirectSide build with a changed main application identity."""
import plistlib
import sys
from pathlib import PurePosixPath
from zipfile import ZipFile


def verify(path):
    with ZipFile(path) as archive:
        for name in archive.namelist():
            entry = PurePosixPath(name)
            if entry.is_absolute() or '..' in entry.parts or '\\' in name:
                raise ValueError('DirectSide build rejected: unsafe archive path.')
            if entry.suffix.lower() in {'.p12', '.pfx', '.key', '.pem', '.p8', '.mobileprovision', '.mobiledevicepairing', '.dpapi'} or entry.name.lower().startswith(('directside-pairing.', 'directside-signing.', 'directside-imported.', 'directside-bootstrap.', 'directside-account.', 'altpairingfile.')):
                raise ValueError('DirectSide build rejected: private signing or pairing material in unsigned IPA.')
        mains = [name for name in archive.namelist()
                 if name.startswith('Payload/') and name.endswith('.app/Info.plist')
                 and name.count('/') == 2]
        if len(mains) != 1:
            raise ValueError('Expected exactly one main application in DirectSide IPA.')
        info = plistlib.loads(archive.read(mains[0]))
        if info.get('CFBundleIdentifier') != 'com.directside.app':
            raise ValueError('DirectSide build rejected: main bundle identifier must remain com.directside.app.')
        return info


if __name__ == '__main__':
    info = verify(sys.argv[1])
    print(f"Verified fixed DirectSide identity: com.directside.app, version {info.get('CFBundleShortVersionString')}, build {info.get('CFBundleVersion')}")
