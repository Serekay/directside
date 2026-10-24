"""Build-time only: official PyInstaller --no-cfg workaround for Unicorn on Windows."""
import hashlib
import json
import os
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path
import pefile

ROOT=Path(__file__).resolve().parents[1]
VERSION='6.22.3'
SHA='05eb2f5615503e72939a7224d68b4aff572c6b0438ee4a17d0a4b481f399362d'
SOURCE=ROOT/'.tools'/('pyinstaller-'+VERSION)
LOADER=SOURCE/'PyInstaller/bootloader/Windows-64bit-intel/runw.exe'

def verify():
    pe=pefile.PE(str(LOADER),fast_load=True)
    if pe.FILE_HEADER.Machine!=0x8664 or pe.OPTIONAL_HEADER.DllCharacteristics&0x4000:raise RuntimeError('Incompatible local emulator bootloader')

def main():
    marker=SOURCE/'directside-bootloader.json'
    if LOADER.is_file() and marker.is_file():verify();return
    archive=ROOT/'.tools'/('pyinstaller-'+VERSION+'.tar.gz')
    if not archive.is_file():
        with urllib.request.urlopen('https://pypi.org/pypi/pyinstaller/'+VERSION+'/json',timeout=30) as response:meta=json.load(response)
        source=next(row for row in meta['urls'] if row['packagetype']=='sdist')
        urllib.request.urlretrieve(source['url'],archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA:raise ValueError('PyInstaller source checksum mismatch')
    if not (SOURCE/'bootloader/waf').is_file():
        with tarfile.open(archive) as package:package.extractall(ROOT/'.tools',filter='data')
    clang=ROOT/'.tools/llvm-mingw-20261020-ucrt-x86_64/bin/x86_64-w64-mingw32-clang.exe'
    compiler=os.environ.get('DIRECTSIDE_BOOTLOADER_CC') or (str(clang) if clang.is_file() else None)
    env=os.environ.copy();args=[sys.executable,'waf','all','--no-cfg','--target-arch=64bit']
    if compiler:
        env['CC']=compiler;env['PATH']=str(Path(compiler).parent)+os.pathsep+env.get('PATH','');args.append('--clang')
    with (ROOT/'build/bootloader-build.log').open('w',encoding='utf-8') as log:
        subprocess.run(args,cwd=SOURCE/'bootloader',env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    verify();marker.write_text(json.dumps({'source_sha256':SHA,'flags':['--no-cfg'],'version':VERSION}))
    print('Local Windows emulator bootloader prepared; system policies unchanged.')

if __name__=='__main__':main()
