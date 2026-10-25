"""Launch the real Windows QML with isolated sample data for documentation.

No signing engine, device commands, account login or release checks are started.
Capture the window with the normal screenshot tool, then close it.
"""
import sys
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'ui'))
from PySide6.QtCore import QUrl
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from common import Preferences
from desktop import DesktopBridge

def main():
    app=QApplication(sys.argv)
    app.setApplicationName('DirectSide Preview')
    app.setWindowIcon(QIcon(str(ROOT/'assets/DirectSide.ico')))
    QQuickStyle.setStyle('Basic')
    with tempfile.TemporaryDirectory(prefix='directside-preview-') as folder:
        bridge=DesktopBridge(start=False,preferences=Preferences(Path(folder)/'preferences.json'))
        bridge.send=lambda _:None
        bridge.initializing=False
        bridge.update(language='en',busy=False,loggedIn=True,authState='ready',
            email='demo@example.com',team='Personal Team',authLocal=True,usbState='ready',
            devices=[{'id':'sample-device','name':'iPhone','label':'iPhone','trusted':True}],
            slotsUsed=2,appIdsLimit=10,appIdsAvailable=8,appIdsRegistered=2,
            developerMode='enabled',status='',success=False)
        engine=QQmlApplicationEngine()
        engine.rootContext().setContextProperty('backend',bridge)
        engine.load(QUrl.fromLocalFile(str(ROOT/'ui/Main.qml')))
        if not engine.rootObjects():return 1
        window=engine.rootObjects()[0]
        window.setTitle('DirectSide Preview')
        window.setIcon(app.windowIcon())
        app.aboutToQuit.connect(bridge.close)
        return app.exec()

if __name__=='__main__':sys.exit(main())
