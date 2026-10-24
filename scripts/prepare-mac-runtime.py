"""Build-time extraction only. Users receive the verified runtime in DirectSide."""
import gzip
import hashlib
import shutil
import struct
import subprocess
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
URL='https://secure-appldnld.apple.com/itunes12/041-56365-20210413-79A5AC6D-6B0A-46EC-B399-5A381183E3BE/iTunes12.8.3.dmg'
DMG_HASH='dd08b9967db3e5847955fa168ce880303abf5f36de12abb2061e7ef1a25be214'
LIB_HASH='2eafc3c79c7f41a8afbfbeaaf23ee5dab5ad5bda55ec8e54dbc0ddf1d20ce630'
OUT=ROOT/'bin/apple/CoreADI.mac'

def digest(path):return hashlib.file_digest(path.open('rb'),'sha256').hexdigest()

def extract_framework(data):
    pos=0
    while pos<len(data):
        magic=data[pos:pos+6];pos+=6
        if magic==b'070707':widths=[6,6,6,6,6,6,6,11,6,11];mode_i,name_i,size_i,pad=2,8,9,False
        elif magic in (b'070701',b'070702'):widths=[8]*13;mode_i,name_i,size_i,pad=1,11,6,True
        else:raise ValueError('Unsupported Apple payload format')
        fields=[]
        for width in widths:fields.append(int(data[pos:pos+width],8 if not pad else 16));pos+=width
        name=data[pos:pos+fields[name_i]-1].decode();pos+=fields[name_i]
        if pad:pos=(pos+3)&~3
        end=pos+fields[size_i]
        if end>len(data):raise ValueError('Truncated Apple payload')
        if name=='TRAILER!!!':break
        if name.lstrip('./')=='System/Library/PrivateFrameworks/CoreADI.framework/Versions/A/CoreADI' and fields[mode_i]&0o170000==0o100000:return data[pos:end]
        pos=(end+3)&~3 if pad else end
    raise ValueError('Apple CoreADI framework not found')

def main():
    if OUT.is_file() and digest(OUT)==LIB_HASH:return
    cache=ROOT/'.tools';cache.mkdir(exist_ok=True)
    dmg=cache/'iTunes12.8.3.dmg'
    if not dmg.is_file():
        with urllib.request.urlopen(URL,timeout=60) as response,dmg.open('wb') as stream:shutil.copyfileobj(response,stream)
    if digest(dmg)!=DMG_HASH:raise ValueError('Apple installer checksum mismatch')
    seven=cache/'7zip-build/7z.exe'
    if not seven.is_file():seven=shutil.which('7z') or shutil.which('7zz')
    if not seven:raise RuntimeError('Build-time 7-Zip extractor is missing')
    unpack=cache/'mac-runtime-extract';unpack.mkdir(exist_ok=True)
    subprocess.run([str(seven),'x',str(dmg),'iTunes/Install iTunes.pkg','-o'+str(unpack),'-y'],check=True,stdout=subprocess.DEVNULL)
    subprocess.run([str(seven),'x',str(unpack/'iTunes/Install iTunes.pkg'),'CoreADI.pkg/Payload','-o'+str(unpack),'-y'],check=True,stdout=subprocess.DEVNULL)
    fat=extract_framework(gzip.decompress((unpack/'CoreADI.pkg/Payload').read_bytes()))
    if fat[:4]!=b'\xca\xfe\xba\xbe':raise ValueError('Expected universal Mach-O')
    image=None
    for i in range(struct.unpack_from('>I',fat,4)[0]):
        cpu,_,offset,size,_=struct.unpack_from('>IIIII',fat,8+i*20)
        if cpu==0x01000007:image=fat[offset:offset+size];break
    if image is None or hashlib.sha256(image).hexdigest()!=LIB_HASH:raise ValueError('Apple CoreADI slice checksum mismatch')
    OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_bytes(image)
    print('Verified local Mac CoreADI runtime prepared.')

if __name__=='__main__':main()
