from pathlib import Path

root = Path(SPECPATH).parent
binaries = [(str(root / 'bin/directside-engine.exe'), 'bin')]
if (root / 'bin/libunwind.dll').exists():
    binaries.append((str(root / 'bin/libunwind.dll'), 'bin'))
if (root / 'bin/apple/CoreADI64.dll').exists():
    binaries.append((str(root / 'bin/apple/CoreADI64.dll'), 'bin/apple'))

a = Analysis([str(root / 'ui/desktop.py')], pathex=[str(root / 'ui')],
    binaries=binaries,
    datas=[(str(root / 'ui/Main.qml'), 'ui'),
           (str(root / 'ui/en.json'), '.'),
           (str(root / 'assets/DirectSide.ico'), 'assets'),
           (str(root / 'assets/localdevvpn-qr.png'), 'assets'),
           (str(root / 'assets/icons'), 'assets/icons'),
           (str(root / 'assets/brand-128.png'), 'assets')],
    hiddenimports=['PySide6.QtQuickControls2','PySide6.QtSvg'],
    excludes=['tkinter', 'PySide6.QtWebEngineCore', 'PySide6.QtWebEngineWidgets'])

# Qt 6.12 uses Windows' unversioned ICU API. A foreign icuuc.dll on PATH
# (e.g. Poppler's version-suffixed ICU exports) shadows it and breaks QtCore.
a.binaries = [entry for entry in a.binaries
              if Path(entry[0]).name.lower() not in ('icuuc.dll', 'icudt78.dll')]
if any('codex-runtimes' in entry[1].lower() for entry in a.binaries):
    raise RuntimeError('A foreign workspace-runtime DLL entered the desktop package.')

pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, a.binaries, a.datas, [], name='DirectSide',
          debug=False, bootloader_ignore_signals=False, strip=False, upx=False,
          console=False, icon=str(root / 'assets/DirectSide.ico'))
