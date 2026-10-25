"""Reject a DirectSide build with a changed main application identity."""
import plistlib
import sys
from zipfile import ZipFile


def verify(path):
    with ZipFile(path) as archive:
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
