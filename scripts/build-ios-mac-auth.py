"""Build the pinned x86 guest TCI interpreter and Mac CoreADI adapter on macOS.

Both the macOS probe and iOS application use TCI. A JIT build cannot silently pass.
"""
import os
from pathlib import Path
import platform
import subprocess

ROOT=Path(__file__).resolve().parents[1]
REVISION='a53ddc9ac6d65b24936d4a37917333fcd816cfd0'

def run(*args,**kwargs):subprocess.run(list(map(str,args)),check=True,**kwargs)

def main():
    if platform.system()!='Darwin':raise RuntimeError('This build needs the Apple SDK on macOS.')
    source=ROOT/'.tools/unicorn-tci'
    if not source.exists():
        run('git','clone','--depth','1','--branch','2.1.4-xcf-a53ddc9','https://github.com/mahee96/unicorn.git',source)
    actual=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
    if actual!=REVISION:raise RuntimeError('Unicorn source revision mismatch')
    for name,sdk,arch,target in [('mac','macosx',platform.machine(),None),('ios','iphoneos','arm64','aarch64-apple-ios')]:
        output=ROOT/'build/mac-auth'/name;output.mkdir(parents=True,exist_ok=True)
        args=['cmake','-S',source,'-B',output,'-DCMAKE_BUILD_TYPE=Release',
            '-DUNICORN_ARCH=x86','-DUNICORN_ENABLE_TCI=ON','-DUNICORN_LOGGING=OFF',
            '-DUNICORN_BUILD_TESTS=OFF','-DUNICORN_BUILD_SAMPLES=OFF','-DUNICORN_INSTALL=OFF',
            '-DBUILD_SHARED_LIBS=OFF','-DUNICORN_LEGACY_STATIC_ARCHIVE=ON',
            '-DCMAKE_OSX_SYSROOT='+sdk,'-DCMAKE_OSX_ARCHITECTURES='+arch]
        if target:args+=['-DCMAKE_SYSTEM_NAME=iOS','-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0','-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY']
        run(*args)
        config=output/'config-host.h'
        text=config.read_text()
        if '#define CONFIG_TCG_INTERPRETER' not in text:
            # The fork emits the flag via CMake's compiler command line instead.
            cache=(output/'CMakeCache.txt').read_text()
            if 'UNICORN_ENABLE_TCI:BOOL=ON' not in cache:raise RuntimeError('TCI is not enabled')
        if target:
            config.write_text(text.replace('#define HAVE_PTHREAD_JIT_PROTECT 1','/* JIT protection unavailable and unnecessary in the interpreter */'))
        run('cmake','--build',output,'--parallel','3')
        if not (output/'libunicorn.a').is_file():raise RuntimeError('Merged interpreter archive is missing')
        pc=output/'pkgconfig';pc.mkdir(exist_ok=True)
        (pc/'unicorn.pc').write_text('Name: unicorn\nDescription: DirectSide x86 TCI only\nVersion: 2.1.5\nLibs: -L'+str(output)+' -lunicorn\nCflags: -I'+str(source/'include')+'\n')
        env=os.environ.copy();env['PKG_CONFIG_PATH']=str(pc);env['PKG_CONFIG_ALLOW_CROSS']='1'
        env['CARGO_TARGET_DIR']=str(ROOT/'build/mac-auth/rust'/name)
        # Force pkg-config to resolve the prebuilt TCI library; never invoke the
        # Rust crate's default CMake path (which would build a JIT interpreter).
        env['UNICORN_STATIC']='1'
        command=['cargo','+stable','build','--locked','--release','--manifest-path',str(ROOT/'vendor/mac-adi-rust/Cargo.toml')]
        if target:command+=['--target',target]
        run(*command,env=env)

if __name__=='__main__':main()
