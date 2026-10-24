"""Qt Quick desktop shell. The signing engine remains a separate local process."""
import json
import sys
from pathlib import Path
from PySide6.QtCore import QObject, Property, Signal, Slot, QProcess, QTimer, QUrl
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication, QFileDialog
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow  # PyInstaller includes the Qt Quick runtime.
from PySide6.QtQuickControls2 import QQuickStyle
from common import ROOT, HOME, Preferences, ipa_identity, valid_code, clean_error


class DesktopBridge(QObject):
    changed = Signal()

    def __init__(self, start=True, preferences=None):
        super().__init__()
        self.preferences=preferences or Preferences()
        saved=self.preferences.load()
        self.data=dict(email=saved.get('email',''),server=saved.get('server','https://new.ani.sidestore.io'),
            loggedIn=False,busy=True,team='',devices=[],deviceIndex=0,ipa='',ipaName='',
            status='Sitzung prüfen …',error='',progress=0,challenge='',numbers=[],teams=[],
            challengeError='',success=False,logs=[],icon=QUrl.fromLocalFile(str(ROOT/'assets'/'brand-128.png')).toString())
        for path in [HOME/'DirectSide.ipa',ROOT/'dist'/'DirectSide.ipa']:
            if path.is_file(): self.data.update(ipa=str(path),ipaName=path.name);break
        self.buffer=bytearray()
        self.initializing=True
        self.installing=False
        self.process=QProcess(self)
        self.process.readyReadStandardOutput.connect(self.read_events)
        self.process.readyReadStandardError.connect(self.read_errors)
        self.process.finished.connect(self.exited)
        self.process.errorOccurred.connect(lambda _:self.fail('Signierkern konnte nicht gestartet werden.'))
        self.timer=QTimer(self);self.timer.setInterval(7000);self.timer.timeout.connect(self.auto_refresh)
        if start: QTimer.singleShot(0,self.start)

    @Property('QVariantMap',notify=changed)
    def state(self):return self.data

    def update(self,**values):self.data.update(values);self.changed.emit()

    def start(self):
        path=ROOT/'bin'/'directside-engine.exe'
        if not path.is_file():self.fail('Signierkern fehlt.');return
        self.process.start(str(path),[]);self.timer.start()

    def send(self,payload):
        if self.process.state()!=QProcess.Running:self.fail('Signierkern nicht erreichbar.');return
        self.process.write((json.dumps(payload,ensure_ascii=False)+'\n').encode())

    def read_events(self):
        self.buffer.extend(bytes(self.process.readAllStandardOutput()))
        while b'\n' in self.buffer:
            line,_,self.buffer=self.buffer.partition(b'\n')
            try:self.handle(json.loads(line))
            except (ValueError,TypeError):pass

    def read_errors(self):
        self.append_log(bytes(self.process.readAllStandardError()).decode('utf-8',errors='replace'))

    def append_log(self,value):
        if value.strip():self.update(logs=(self.data['logs']+[clean_error(value)])[-150:])

    def fail(self,message):
        self.installing=False
        self.update(error=clean_error(message),busy=False,challenge='',status='Fehlgeschlagen')
        self.append_log(message)

    def handle(self,event):
        kind=event.get('event')
        if kind=='ready':self.send({'command':'restore'})
        elif kind in ('logged_in','logged_out'):
            logged=kind=='logged_in'
            email=event.get('email') or self.data['email']
            self.update(loggedIn=logged,email=email,team=event.get('team',''),busy=False,challenge='',status='Bereit' if logged else 'Anmeldung erforderlich')
            if email:self.persist(email,self.data['server'])
            if self.initializing:self.initializing=False;self.refresh()
        elif kind=='devices':
            old=self.data['devices'];index=self.data['deviceIndex']
            selected=old[index].get('id') if old and index<len(old) else None
            devices=event.get('devices',[])
            index=next((i for i,d in enumerate(devices) if d.get('id')==selected),0)
            self.update(devices=devices,deviceIndex=index,busy=False)
        elif kind=='status':self.update(status=event.get('message',''));self.append_log(event.get('message',''))
        elif kind=='progress':self.update(progress=event.get('value',0))
        elif kind=='two_factor':self.update(challenge='code',busy=True,numbers=event.get('numbers',[]),challengeError='Code nicht akzeptiert' if event.get('last_error') else '')
        elif kind=='choose_team':self.update(challenge='team',busy=True,teams=event.get('teams',[]))
        elif kind=='pairing_pin':self.update(challenge='pairing',busy=True)
        elif kind=='error':self.fail(event.get('message','Unbekannter Fehler'))
        elif kind=='installed':self.installing=False;self.update(busy=False,success=True,progress=100,status='Installiert',challenge='')

    def persist(self,email,server):
        try:self.preferences.save(email,server);return True
        except OSError:self.fail('Account-Einstellungen konnten nicht gespeichert werden.');return False

    @Slot(str,str)
    def login(self,email,password):
        if self.data['busy']:return
        if not email.strip() or not password:self.fail('Apple-ID und Passwort eingeben.');return
        if not self.persist(email,self.data['server']):return
        self.update(email=email.strip(),busy=True,error='',status='Bei Apple anmelden …',success=False)
        self.send({'command':'login','email':email.strip(),'password':password,'server':self.data['server']})

    @Slot()
    def logout(self):
        if not self.data['busy']:self.update(busy=True);self.send({'command':'logout'})

    @Slot()
    def refresh(self):
        if self.data['busy']:return
        self.update(busy=True);self.send({'command':'devices'})

    def auto_refresh(self):
        if not self.initializing and not self.data['busy'] and not self.data['devices']:self.refresh()

    @Slot(int)
    def selectDevice(self,index):
        if 0<=index<len(self.data['devices']):self.update(deviceIndex=index)

    @Slot(str)
    def submitCode(self,code):
        if self.data['challenge'] not in ('code','pairing'):return
        if self.data['challenge']=='code' and not valid_code(code):self.update(challengeError='6 Ziffern eingeben');return
        payload={'action':'code','code':code} if self.data['challenge']=='code' else {'code':code}
        self.update(challenge='',challengeError='',status='Bestätigung prüfen …');self.send(payload)

    @Slot(str,int)
    def requestCode(self,action,number=0):
        if self.data['challenge']!='code':return
        self.update(challenge='',challengeError='');self.send({'action':action,'number_id':number})

    @Slot(str)
    def selectTeam(self,team):
        if self.data['challenge']=='team':self.update(challenge='');self.send({'team_id':team})

    @Slot()
    def cancelChallenge(self):
        kind=self.data['challenge']
        if kind:self.update(challenge='');self.send({'team_id':''} if kind=='team' else {'code':''} if kind=='pairing' else {'action':'cancel'})

    @Slot()
    def chooseIPA(self):
        if self.data['busy']:return
        path,_=QFileDialog.getOpenFileName(None,'IPA auswählen',str(HOME),'iPhone-App (*.ipa)')
        if path:self.update(ipa=path,ipaName=Path(path).name,success=False,error='')

    @Slot()
    def install(self):
        if self.data['busy'] or not self.data['loggedIn'] or not self.data['devices']:return
        path=Path(self.data['ipa'])
        try:bundle=ipa_identity(path)
        except Exception:self.fail('Keine gültige IPA ausgewählt.');return
        self.installing=True
        self.update(busy=True,progress=0,error='',success=False,status='Installation vorbereiten …')
        self.send({'command':'install','device_id':self.data['devices'][self.data['deviceIndex']]['id'],'path':str(path),'bundle_id':bundle,'bootstrap':bundle=='com.directside.app'})

    @Slot(str)
    def saveServer(self,server):
        from urllib.parse import urlsplit
        url=urlsplit(server)
        if url.scheme!='https' or not url.hostname or url.username or url.query or url.fragment:self.fail('Gültige HTTPS-Adresse eingeben.');return
        if self.persist(self.data['email'],server):self.update(server=server,error='',status='Gespeichert')

    @Slot()
    def dismissError(self):self.update(error='')

    def exited(self,*_):
        if self.process.state()==QProcess.NotRunning:self.fail('Signierkern beendet. DirectSide neu starten.')

    def close(self):
        self.timer.stop()
        if self.process.state()!=QProcess.NotRunning:self.process.terminate();self.process.waitForFinished(1500)


def main():
    if sys.platform=='win32':
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('DirectSide.Desktop')
    app=QApplication(sys.argv);app.setApplicationName('DirectSide');app.setWindowIcon(QIcon(str(ROOT/'assets'/'DirectSide.ico')))
    QQuickStyle.setStyle('Basic')
    smoke='--smoke-test' in sys.argv
    bridge=DesktopBridge(start=not smoke)
    engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',bridge)
    engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')))
    if not engine.rootObjects():return 1
    engine.rootObjects()[0].setIcon(app.windowIcon())
    app.aboutToQuit.connect(bridge.close)
    if smoke:
        output=Path(sys.argv[sys.argv.index('--smoke-test')+1])
        window=engine.rootObjects()[0];window.hide()
        probe=QProcess(app);captured=bytearray();done=False
        def read_probe():captured.extend(bytes(probe.readAllStandardOutput()))
        def finish(code=-1,*_):
            nonlocal done
            if done:return
            done=True
            read_probe()
            from PySide6.QtCore import Qt
            result={'qt_loaded':True,'qml_loaded':bool(engine.rootObjects()),
                'window_icon':not window.icon().isNull(),'custom_frame':bool(window.flags() & Qt.FramelessWindowHint),
                'engine_ready':any(b'"event":"ready"' in line for line in captured.splitlines()),'engine_exit':code}
            result['passed']=all(result[k] for k in ['qt_loaded','qml_loaded','window_icon','custom_frame','engine_ready']) and code==0
            output.parent.mkdir(parents=True,exist_ok=True)
            output.write_text(json.dumps(result,indent=2),encoding='utf-8')
            if probe.state()!=QProcess.NotRunning:probe.kill();probe.waitForFinished(1000)
            app.exit(0 if result['passed'] else 1)
        probe.readyReadStandardOutput.connect(read_probe)
        probe.finished.connect(finish)
        probe.errorOccurred.connect(lambda _:finish(-1))
        probe.started.connect(lambda:probe.write(b'{"command":"quit"}\n'))
        probe.start(str(ROOT/'bin'/'directside-engine.exe'),[])
        QTimer.singleShot(15000,lambda:finish(-1))
    return app.exec()

if __name__=='__main__':sys.exit(main())
