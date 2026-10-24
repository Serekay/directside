"""Prepare pinned Apple ARM64 runtime resources; no credentials or provisioning data."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import build_opener,HTTPRedirectHandler
from zipfile import ZipFile

URL='https://apps.mzstatic.com/content/android-apple-music-apk/applemusic.apk'
APK_SHA256='9aab4e3bfd44b509dd657b030d46df536c5592512c256fc59012cce47a2e9c9c'
LIBRARIES={
    'libCoreADI.so':'9d5b557cf3faf88c34c394ab2cd7fc1a3b4acf3aed51f28cd0bc093858107c22',
    'libstoreservicescore.so':'bd335e6963ba5ae2f5babca613435ad56d2660a9aee37df35f876c458d105ce4',
}

class AppleRedirects(HTTPRedirectHandler):
    def redirect_request(self,request,fp,code,message,headers,new_url):
        parsed=urlsplit(new_url);host=parsed.hostname or ''
        if parsed.scheme!='https' or not (host=='mzstatic.com' or host.endswith('.mzstatic.com') or host=='apple.com' or host.endswith('.apple.com')) or parsed.username or parsed.password:raise RuntimeError('Unexpected Apple runtime download redirect.')
        return super().redirect_request(request,fp,code,message,headers,new_url)

def sha256(path):
    with path.open('rb') as file:return hashlib.file_digest(file,'sha256').hexdigest()

def prepare(apk,output):
    if not apk.is_file():
        apk.parent.mkdir(parents=True,exist_ok=True);partial=apk.with_suffix('.download')
        with build_opener(AppleRedirects()).open(URL,timeout=60) as response,partial.open('wb') as file:
            size=0
            while block:=response.read(1024*1024):
                size+=len(block)
                if size>300_000_000:raise RuntimeError('Apple package exceeds the expected size.')
                file.write(block)
        if sha256(partial)!=APK_SHA256:raise RuntimeError('Apple package changed. Review and pin the new runtime before building.')
        partial.replace(apk)
    if sha256(apk)!=APK_SHA256:raise RuntimeError('Apple package checksum mismatch.')
    output.mkdir(parents=True,exist_ok=True)
    with ZipFile(apk) as archive:
        for name,digest in LIBRARIES.items():
            data=archive.read('lib/arm64-v8a/'+name)
            if hashlib.sha256(data).hexdigest()!=digest:raise RuntimeError('Apple library checksum mismatch: '+name)
            if data[:6]!=b'\x7fELF\x02\x01' or int.from_bytes(data[18:20],'little')!=183:raise RuntimeError('Expected an ARM64 ELF runtime: '+name)
            (output/name).write_bytes(data)
    (output/'provenance.json').write_text(json.dumps({'source':URL,'apk_sha256':APK_SHA256,'libraries':LIBRARIES},indent=2),encoding='utf-8')
    print('Verified Apple ARM64 runtime: 2 libraries, no account data.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--apk',type=Path,default=Path('build/runtime-cache/applemusic.apk'));parser.add_argument('--output',type=Path,default=Path('ios/Resources/AnisetteRuntime'))
    options=parser.parse_args();prepare(options.apk,options.output)
