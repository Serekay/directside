"""Qt Quick desktop shell. The signing engine remains a separate local process."""
import json
import sys
import threading
import time
from pathlib import Path
from PySide6.QtCore import QObject, Property, Signal, Slot, QProcess, QTimer, QUrl
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication, QFileDialog
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow  # PyInstaller includes the Qt Quick runtime.
from PySide6.QtQuickControls2 import QQuickStyle
from common import ROOT, HOME, Preferences, ipa_identity, valid_code, clean_error
from components import usb_status, setup_apple, download_livecontainer
from i18n import ENGLISH, translate


class DesktopBridge(QObject):
    changed = Signal()
    setupEvent = Signal(dict)

    def __init__(self, start=True, preferences=None):
        super().__init__()
        self.preferences=preferences or Preferences()
        saved=self.preferences.load()
        language=saved.get('language','en')
        self.data=dict(email=saved.get('email',''),authLocal=False,usbState=usb_status(),setupBusy=False,vpnState='unknown',lcState='unknown',directsidePresent=False,lcPrepared=False,slotsUsed=-1,developerApps=[],installedApps=[],
            loggedIn=False,busy=True,scanning=False,team='',devices=[],deviceIndex=0,ipa='',ipaName='',
            status='Sitzung prüfen …',error='',progress=0,challenge='',numbers=[],teams=[],
            challengeError='',success=False,logs=[],icon=QUrl.fromLocalFile(str(ROOT/'assets'/'brand-128.png')).toString(),vpnQr=QUrl.fromLocalFile(str(ROOT/'assets'/'localdevvpn-qr.png')).toString())
        for path in [HOME/'DirectSide.ipa',ROOT/'dist'/'DirectSide.ipa']:
            if path.is_file(): self.data.update(ipa=str(path),ipaName=path.name);break
        self.data.update(language=language,translations=ENGLISH,status=translate(self.data['status'],language))
        self.buffer=bytearray()
        self.initializing=True
        self.installing=False
        self.componentDevice=None;self.componentTime=0
        self.process=QProcess(self)
        self.process.readyReadStandardOutput.connect(self.read_events)
        self.process.readyReadStandardError.connect(self.read_errors)
        self.process.finished.connect(self.exited)
        self.process.errorOccurred.connect(lambda _:self.fail('Signierkern konnte nicht gestartet werden.'))
        self.timer=QTimer(self);self.timer.setInterval(3000);self.timer.timeout.connect(self.auto_refresh)
        self.setupEvent.connect(self.onSetupEvent)
        if start: QTimer.singleShot(0,self.start)

    @Property('QVariantMap',notify=changed)
    def state(self):return self.data

    def update(self,**values):
        language=values.get('language',self.data['language'])
        for key in ('status','error','challengeError'):
            if key in values:values[key]=translate(values[key],language)
        self.data.update(values);self.changed.emit()

    @Slot(str)
    def setLanguage(self,language):
        if language not in ('en','de'):return
        try:self.preferences.save(self.data['email'],language)
        except OSError:self.fail('Account-Einstellungen konnten nicht gespeichert werden.');return
        self.update(language=language,**{key:self.data[key] for key in ('status','error','challengeError')},logs=[translate(line,language) for line in self.data['logs']])

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
        if value.strip():self.update(logs=(self.data['logs']+[translate(clean_error(value),self.data['language'])])[-150:])

    @Slot()
    def copyActivity(self):
        QApplication.clipboard().setText('\n\n'.join(self.data['logs']))

    def fail(self,message):
        self.installing=False
        self.update(error=clean_error(message),busy=False,scanning=False,challenge='',status='Fehlgeschlagen')
        self.append_log(message)

    def handle(self,event):
        kind=event.get('event')
        if kind=='ready':self.send({'command':'local_auth_probe'})
        elif kind=='local_auth_ready':self.update(authLocal=True);self.send({'command':'restore'})
        elif kind in ('logged_in','logged_out'):
            logged=kind=='logged_in'
            email=event.get('email') or self.data['email']
            self.update(loggedIn=logged,email=email,team=event.get('team',''),busy=False,challenge='',status='Bereit' if logged else 'Anmeldung erforderlich')
            if email:self.persist(email)
            if self.initializing:self.initializing=False;self.refresh()
        elif kind=='devices':
            old=self.data['devices'];index=self.data['deviceIndex']
            selected=old[index].get('id') if old and index<len(old) else None
            devices=event.get('devices',[])
            for device in devices:device['label']=device.get('name','Apple-Gerät')+' · '+device['id'][-4:]
            index=next((i for i,d in enumerate(devices) if d.get('id')==selected),0)
            if devices and devices[index]['id']!=selected:self.update(installedApps=[],slotsUsed=-1,developerApps=[],lcPrepared=False)
            self.update(devices=devices,deviceIndex=index,busy=False,scanning=False)
            if devices:
                if devices[index]['id']!=self.componentDevice or time.monotonic()-self.componentTime>30:self.inspectDevice()
            else:
                self.componentDevice=None
                self.update(vpnState='unknown',lcState='unknown',directsidePresent=False,lcPrepared=False,slotsUsed=-1,developerApps=[],installedApps=[])
        elif kind=='device_components':
            if self.data['devices'] and event.get('device_id')==self.data['devices'][self.data['deviceIndex']]['id']:
                self.componentDevice=event['device_id'];self.componentTime=time.monotonic()
                cached={app['id']:app for app in self.data['installedApps']}
                apps=[dict(app,icon=cached.get(app['id'],{}).get('icon',''),iconChecked=cached.get(app['id'],{}).get('iconChecked',False)) for app in event.get('apps',[])]
                self.update(vpnState='installed' if event.get('localdevvpn') else 'missing',lcState='installed' if event.get('livecontainer') else 'missing',directsidePresent=bool(event.get('directside')),slotsUsed=event.get('slots_used',-1),developerApps=event.get('developer_apps',[]),installedApps=apps,busy=False,scanning=False)
        elif kind=='app_icons':
            if self.data['devices'] and event.get('device_id')==self.data['devices'][self.data['deviceIndex']]['id']:
                icons={icon['id']:icon.get('png','') for icon in event.get('icons',[])}
                apps=[dict(app,icon=('data:image/png;base64,'+icons[app['id']]) if icons[app['id']] else '',iconChecked=True) if app['id'] in icons else app for app in self.data['installedApps']]
                self.update(installedApps=apps,busy=False,scanning=False)
        elif kind=='livecontainer_prepared':self.update(busy=False,lcPrepared=True,status='Auf dem iPhone: DirectSide → Konto → LiveContainer einrichten')
        elif kind=='status':self.update(status=event.get('message',''));self.append_log(event.get('message',''))
        elif kind=='progress':self.update(progress=event.get('value',0))
        elif kind=='two_factor':self.update(challenge='code',busy=True,numbers=event.get('numbers',[]),challengeError='Code nicht akzeptiert' if event.get('last_error') else '')
        elif kind=='choose_team':self.update(challenge='team',busy=True,teams=event.get('teams',[]))
        elif kind=='pairing_pin':self.update(challenge='pairing',busy=True)
        elif kind=='error':
            if event.get('command')=='app_icons':
                apps=[dict(app,iconChecked=True) if app['id'] in getattr(self,'requestedIcons',[]) else app for app in self.data['installedApps']]
                self.update(busy=False,scanning=False,installedApps=apps)
                self.append_log('App-Icons konnten nicht geladen werden.');return
            if event.get('command')=='device_components':
                self.componentDevice=None
                self.update(busy=False,scanning=False,vpnState='unknown',lcState='unknown',directsidePresent=False,slotsUsed=-1,developerApps=[],installedApps=[])
                self.append_log('App-Prüfung nicht möglich. iPhone entsperren und Vertrauen bestätigen.');return
            self.fail(event.get('message','Unbekannter Fehler'))
            if event.get('command')=='local_auth_probe' and self.initializing:self.initializing=False;self.refresh()
        elif kind=='installed':self.installing=False;self.update(busy=False,success=True,progress=100,status='Installiert',challenge='');self.inspectDevice()

    def persist(self,email):
        try:self.preferences.save(email,self.data['language']);return True
        except OSError:self.fail('Account-Einstellungen konnten nicht gespeichert werden.');return False

    @Slot(str,str)
    def login(self,email,password):
        if self.data['busy']:return
        if not email.strip() or not password:self.fail('Apple-ID und Passwort eingeben.');return
        if not self.persist(email):return
        self.update(email=email.strip(),busy=True,error='',status='Bei Apple anmelden …',success=False)
        self.send({'command':'login','email':email.strip(),'password':password})

    @Slot()
    def logout(self):
        if not self.data['busy']:self.update(busy=True);self.send({'command':'logout'})

    @Slot()
    def refresh(self):
        if self.data['busy']:return
        self.componentDevice=None
        self.update(busy=True,scanning=True);self.send({'command':'devices'})

    def auto_refresh(self):
        if not self.initializing and not self.data['busy']:
            self.update(busy=True,scanning=True);self.send({'command':'devices'})

    @Slot(int)
    def selectDevice(self,index):
        if not self.data['busy'] and 0<=index<len(self.data['devices']):self.update(deviceIndex=index,lcPrepared=False,installedApps=[]);self.inspectDevice()

    @Slot('QVariantList')
    def loadAppIcons(self,bundles):
        if self.data['busy'] or not self.data['devices']:return
        wanted={app['id'] for app in self.data['installedApps'] if not app.get('iconChecked')}
        selected=[bundle for bundle in bundles if isinstance(bundle,str) and bundle in wanted][:12]
        if not selected:return
        self.requestedIcons=selected
        self.update(busy=True,scanning=True)
        self.send({'command':'app_icons','device_id':self.data['devices'][self.data['deviceIndex']]['id'],'bundles':selected})

    @Slot()
    def inspectDevice(self):
        if self.data['busy'] or not self.data['devices']:return
        self.update(busy=True,scanning=True,vpnState='unknown',lcState='unknown',directsidePresent=False,slotsUsed=-1,developerApps=[])
        self.send({'command':'device_components','device_id':self.data['devices'][self.data['deviceIndex']]['id']})

    @Slot()
    def installLiveContainer(self):
        if self.data['busy'] or not self.data['loggedIn'] or not self.data['devices']:return
        self.update(busy=True,setupBusy=True,error='',progress=0,status='LiveContainer vorbereiten …')
        self.lcDevice=self.data['devices'][self.data['deviceIndex']]['id']
        def worker():
            try:download_livecontainer(self.setupEvent.emit)
            except Exception as error:self.setupEvent.emit({'type':'error','message':str(error)})
        threading.Thread(target=worker,daemon=True).start()

    @Slot()
    def prepareLiveContainer(self):
        if self.data['busy'] or not self.data['loggedIn'] or self.data['lcState']!='installed' or not self.data['directsidePresent']:return
        self.update(busy=True,error='',lcPrepared=False,status='Zertifikat lokal übertragen …')
        self.send({'command':'prepare_livecontainer','device_id':self.data['devices'][self.data['deviceIndex']]['id']})

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
        path,_=QFileDialog.getOpenFileName(None,translate('IPA auswählen',self.data['language']),str(HOME),'iPhone app (*.ipa)')
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

    @Slot()
    def dismissError(self):self.update(error='')

    @Slot()
    def checkComponents(self):
        if self.data['busy']:return
        self.update(usbState=usb_status(),error='',busy=True)
        self.send({'command':'local_auth_probe'})

    @Slot()
    def setupComponents(self):
        if self.data['busy']:return
        self.update(busy=True,setupBusy=True,error='',progress=0,status='Komponenten prüfen …')
        def worker():
            try:setup_apple(self.setupEvent.emit)
            except Exception as error:self.setupEvent.emit({'type':'error','message':str(error)})
        threading.Thread(target=worker,daemon=True).start()

    @Slot(dict)
    def onSetupEvent(self,event):
        kind=event.get('type')
        if kind=='progress':self.update(progress=event.get('value',0))
        elif kind=='status':self.update(status=event.get('message',''))
        elif kind=='error':self.update(setupBusy=False,usbState=usb_status());self.fail(event.get('message','Einrichtung fehlgeschlagen.'))
        elif kind=='livecontainer_downloaded':
            try:
                path=Path(event['path']);bundle=ipa_identity(path)
                if bundle!='com.kdt.livecontainer':raise ValueError('Unerwartete LiveContainer-Bundle-ID.')
            except Exception as error:self.update(setupBusy=False);self.fail(str(error));return
            self.installing=True
            self.update(setupBusy=False,status='LiveContainer signieren und installieren …',progress=0)
            self.send({'command':'install','device_id':self.lcDevice,'path':str(path),'bundle_id':bundle,'bootstrap':False})
        elif kind=='done':
            self.update(busy=False,setupBusy=False,usbState=usb_status(),status=event.get('message',''),progress=0)
            self.checkComponents()

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
            result['local_authentication']=any(b'"event":"local_auth_ready"' in line for line in captured.splitlines())
            result['passed']=all(result[k] for k in ['qt_loaded','qml_loaded','window_icon','custom_frame','engine_ready','local_authentication']) and code==0
            output.parent.mkdir(parents=True,exist_ok=True)
            output.write_text(json.dumps(result,indent=2),encoding='utf-8')
            if probe.state()!=QProcess.NotRunning:probe.kill();probe.waitForFinished(1000)
            app.exit(0 if result['passed'] else 1)
        probe.readyReadStandardOutput.connect(read_probe)
        probe.finished.connect(finish)
        probe.errorOccurred.connect(lambda _:finish(-1))
        probe.started.connect(lambda:probe.write(b'{"command":"local_auth_probe"}\n{"command":"quit"}\n'))
        probe.start(str(ROOT/'bin'/'directside-engine.exe'),[])
        QTimer.singleShot(15000,lambda:finish(-1))
    return app.exec()

if __name__=='__main__':sys.exit(main())
