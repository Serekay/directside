from pathlib import Path
import sys
from PyInstaller.utils.hooks import collect_all
from PyInstaller.utils.win32.versioninfo import VSVersionInfo, FixedFileInfo, StringFileInfo, StringTable, StringStruct, VarFileInfo, VarStruct
unicorn_data,unicorn_binaries,unicorn_imports=collect_all('unicorn')
unicorn_data=[row for row in unicorn_data if not row[0].lower().endswith(('.lib','.a'))]

root = Path(SPECPATH).parent
sys.path.insert(0,str(root/'ui'))
from updates import VERSION, BUILD
number=tuple(int(part) for part in VERSION.split('.'))+(BUILD,)
version_info=VSVersionInfo(ffi=FixedFileInfo(filevers=number,prodvers=number,mask=0x3f,flags=0,OS=0x40004,fileType=1,subtype=0,date=(0,0)),kids=[
    StringFileInfo([StringTable('040904B0',[
        StringStruct('FileDescription','DirectSide'),StringStruct('ProductName','DirectSide'),
        StringStruct('FileVersion',VERSION+'.'+str(BUILD)),StringStruct('ProductVersion',VERSION+' ('+str(BUILD)+')'),
        StringStruct('OriginalFilename','DirectSide.exe')])]),VarFileInfo([VarStruct('Translation',[1033,1200])])])
class DirectSideEXE(EXE):
    # Official PyInstaller workaround for Unicorn's longjmp/CFG incompatibility.
    # Use only our local build; leave the installed PyInstaller bootloaders intact.
    def _bootloader_file(self, exe, extension=None):
        path=root/'.tools/pyinstaller-6.22.3/PyInstaller/bootloader/Windows-64bit-intel/runw.exe'
        if not path.is_file():raise RuntimeError('Build the DirectSide bootloader first.')
        return str(path)
binaries = [(str(root / 'bin/directside-engine.exe'), 'bin')]
if (root / 'bin/libunwind.dll').exists():
    binaries.append((str(root / 'bin/libunwind.dll'), 'bin'))

a = Analysis([str(root / 'ui/desktop.py')], pathex=[str(root / 'ui')],
    binaries=binaries+unicorn_binaries,
    datas=[(str(root / 'ui/Main.qml'), 'ui'),
           (str(root / 'ui/en.json'), '.'),
           (str(root / 'assets/DirectSide.ico'), 'assets'),
           (str(root / 'assets/icons'), 'assets/icons'),
           (str(root / 'assets/apple_root.cer'), 'assets'),
           (str(root / 'bin/apple/CoreADI.mac'), 'bin/apple'),
           (str(root / 'vendor/mac-adi-python'), 'vendor/mac-adi-python'),
           (str(root / 'licenses'), 'licenses'),
           (str(root / 'THIRD_PARTY.md'), '.'),
           (str(root / 'assets/brand-128.png'), 'assets')]+unicorn_data,
    hiddenimports=['PySide6.QtQuickControls2','PySide6.QtSvg','local_mac_auth','unicorn']+unicorn_imports,
    excludes=['tkinter', 'PySide6.QtWebEngineCore', 'PySide6.QtWebEngineWidgets'])

# Qt 6.12 uses Windows' unversioned ICU API. A foreign icuuc.dll on PATH
# (e.g. Poppler's version-suffixed ICU exports) shadows it and breaks QtCore.
a.binaries = [entry for entry in a.binaries
              if Path(entry[0]).name.lower() not in ('icuuc.dll', 'icudt78.dll')]
if any('codex-runtimes' in entry[1].lower() for entry in a.binaries):
    raise RuntimeError('A foreign workspace-runtime DLL entered the desktop package.')

pyz = PYZ(a.pure)
exe = DirectSideEXE(pyz, a.scripts, a.binaries, a.datas, [], name='DirectSide',
          debug=False, bootloader_ignore_signals=False, strip=False, upx=False,
          console=False, version=version_info, icon=str(root / 'assets/DirectSide.ico'))
