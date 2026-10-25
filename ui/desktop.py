"""Qt Quick desktop shell. The signing engine remains a separate local process."""
import json
import os
import sys
if '--local-anisette' in sys.argv:
    from local_mac_auth import main as local_auth_main
    sys.exit(local_auth_main())
if '--apply-update' in sys.argv:
    from updates import apply_update
    sys.exit(apply_update(sys.argv[sys.argv.index('--apply-update')+1:]))
if '--release-probe' in sys.argv:
    from pathlib import Path
    from updates import ReleaseClient
    from common import HOME, ROOT
    output=Path(sys.argv[sys.argv.index('--release-probe')+1])
    try:
        client=ReleaseClient(HOME if getattr(sys,'frozen',False) else ROOT)
        authenticated=bool(client.token())
        release=client.latest()
        result={'ok':True,'authenticated':authenticated,'latest':release['tag_name'] if release else None}
    except Exception:
        result={'ok':False}
    output.write_text(json.dumps(result),encoding='utf-8')
    sys.exit(0 if result['ok'] else 1)
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
from updates import ReleaseClient, VERSION, version, digest, CACHE, UpdateError


class DesktopBridge(QObject):
    changed = Signal()
    setupEvent = Signal(dict)
    releaseEvent = Signal(dict)

    def __init__(self, start=True, preferences=None):
        super().__init__()
        self.preferences=preferences or Preferences()
        saved=self.preferences.load()
        language=saved.get('language','en')
        self.data=dict(email=saved.get('email',''),authLocal=False,usbState=usb_status(),setupBusy=False,vpnState='unknown',lcState='unknown',directsidePresent=False,lcPrepared=False,slotsUsed=-1,developerApps=[],installedApps=[],
            loggedIn=False,authState='checking',appIdsLimit=-1,appIdsAvailable=-1,appIdsRegistered=-1,busy=True,scanning=False,team='',devices=[],deviceIndex=0,ipa='',ipaName='',
            status='Sitzung prüfen …',error='',progress=0,challenge='',numbers=[],teams=[],
            challengeError='',success=False,logs=[],icon=QUrl.fromLocalFile(str(ROOT/'assets'/'brand-128.png')).toString(),vpnQr=QUrl.fromLocalFile(str(ROOT/'assets'/'localdevvpn-qr.png')).toString())
        for path in [HOME/'DirectSide.ipa',ROOT/'dist'/'DirectSide.ipa']:
            if path.is_file(): self.data.update(ipa=str(path),ipaName=path.name);break
        self.data.update(language=language,savedEmail=saved.get('email',''),translations=ENGLISH,status=translate(self.data['status'],language))
        self.data.update(version=VERSION,updateBusy=False,updateProgress=0,updateState='unchecked',updateMessage='',releaseVersion='',windowsUpdate=False,releaseIPA=False,directsideInstalling=False,customIPA='',customIPAName='',ipaSource='file',githubSaved=(CACHE/'github.dpapi').is_file())
        self.data.update(certificates=[],certificatesLoaded=False,certificateTeam='',certificateLimit=False,removal={},developerMode='unknown',settingUp=False,setupPhase='')
        self.data.update(signingMode=saved.get('signing_mode','account'),importedIdentity={},identityP12='',identityProfiles=[],canSign=False)
        self.data.update(appIds=[],appIdsLoading=False,appIdsError='')
        self.setupRecord=self.preferences.path.with_name('pending-setup.json')
        try:
            self.pendingSetup=json.loads(self.setupRecord.read_text(encoding='utf-8'))
            if not isinstance(self.pendingSetup,dict) or not all(isinstance(self.pendingSetup.get(k),str) for k in ('device','path','mode','email')):self.pendingSetup=None
        except (OSError,ValueError):self.pendingSetup=None
        self.data.update(setupPending=bool(self.pendingSetup),setupReady=False)
        self.data.update(usbTrustPending=False)
        self.trustRejected=False
        self.releaseClient=ReleaseClient(HOME if getattr(sys,'frozen',False) else ROOT)
        self.release=None
        self.buffer=bytearray()
        self.initializing=True
        self.installing=False
        self.setupWasFirstInstall=False
        self.pendingLogin=None
        self.pendingReleaseInstall=None
        self.componentDevice=None;self.componentTime=0
        self.process=QProcess(self)
        self.process.readyReadStandardOutput.connect(self.read_events)
        self.process.readyReadStandardError.connect(self.read_errors)
        self.process.finished.connect(self.exited)
        self.process.errorOccurred.connect(lambda _:self.fail('Signierkern konnte nicht gestartet werden.'))
        self.timer=QTimer(self);self.timer.setInterval(3000);self.timer.timeout.connect(self.auto_refresh)
        self.setupEvent.connect(self.onSetupEvent)
        self.releaseEvent.connect(self.onReleaseEvent)
        self.updateTimer=QTimer(self);self.updateTimer.setInterval(6*60*60*1000);self.updateTimer.timeout.connect(self.checkUpdates)
        if start:
            QTimer.singleShot(0,self.start)
            QTimer.singleShot(2500,self.checkUpdates)
            self.updateTimer.start()
            report=CACHE/'last-update.json'
            if report.is_file():
                try:
                    outcome=json.loads(report.read_text(encoding='utf-8'))
                    self.data['updateMessage']=outcome.get('message','Windows-Update installiert.')
                    self.data['updateState']='current' if outcome.get('ok') else 'error'
                    report.unlink()
                except (OSError,ValueError):pass

    @Property('QVariantMap',notify=changed)
    def state(self):return self.data

    def update(self,**values):
        language=values.get('language',self.data['language'])
        for key in ('status','error','challengeError'):
            if key in values:values[key]=translate(values[key],language)
        self.data.update(values)
        self.data['canSign']=bool(self.data['importedIdentity']) and self.data['importedIdentity'].get('valid',True) if self.data['signingMode']=='imported' else self.data['loggedIn']
        self.changed.emit()
        if not self.data['busy'] and self.pendingLogin is not None:QTimer.singleShot(0,self.startPendingLogin)
        elif not self.data['busy'] and self.pendingReleaseInstall is not None:QTimer.singleShot(0,self.startPendingReleaseInstall)

    @Slot(str)
    def editEmail(self,value):
        # Keep the draft in state so unrelated USB updates cannot restore an old value.
        self.data['email']=value

    def startPendingLogin(self):
        if self.pendingLogin is None or self.data['busy']:return
        email,password=self.pendingLogin;self.pendingLogin=None
        self.login(email,password)

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
        self.pendingLogin=None
        self.pendingReleaseInstall=None
        if not self.data['loggedIn']:self.data['authState']='signed_out'
        self.update(error=clean_error(message),busy=False,scanning=False,challenge='',directsideInstalling=False,settingUp=False,setupPhase='',status='Fehlgeschlagen')
        self.append_log(message)

    def handle(self,event):
        kind=event.get('event')
        if kind=='ready':self.send({'command':'imported_identity'});self.send({'command':'local_auth_probe'})
        elif kind=='local_auth_ready':self.update(authLocal=True);self.send({'command':'restore'})
        elif kind in ('logged_in','logged_out'):
            self.data.update(certificates=[],certificatesLoaded=False,certificateTeam='',certificateLimit=False,removal={})
            self.data.update(appIds=[],appIdsLoading=False,appIdsError='')
            logged=kind=='logged_in'
            email=event.get('email') or self.data['email']
            state='signed_in' if logged else event.get('reason','signed_out')
            self.update(loggedIn=logged,authState=state,email=email,team=event.get('team',''),busy=False,challenge='',status='Bereit' if logged else 'Sitzung abgelaufen · bitte anmelden' if state=='expired' else 'Anmeldung erforderlich',**({} if logged else dict(appIdsLimit=-1,appIdsAvailable=-1,appIdsRegistered=-1)))
            if email:self.persist(email)
            if self.initializing:self.initializing=False;self.refresh()
            elif logged and self.pendingSetup:self.componentDevice=None;self.inspectDevice()
        elif kind=='imported_identity':
            identity=event.get('identity') or {}
            self.update(importedIdentity=identity,busy=False,status='Zertifikat geprüft.' if identity else 'Kein Zertifikat importiert.')
        elif kind=='account_quota':
            self.update(appIdsLimit=event.get('limit') if event.get('limit') is not None else -1,appIdsAvailable=event.get('available') if event.get('available') is not None else -1,appIdsRegistered=event.get('registered',-1))
        elif kind=='app_ids':
            ids=sorted(event.get('ids',[]),key=lambda item:item.get('name','').casefold())
            names={'ShareExtension':'Teilen','LaunchAppExtension':'App-Start','LiveProcess':'App-Ausführung','AltWidgetExtension':'Widget'}
            ids=[dict(item,displayName=names.get(item.get('name'),item.get('name',''))) for item in ids]
            self.update(appIds=ids,appIdsLoading=False,appIdsError='',appIdsRegistered=len(ids),appIdsLimit=event.get('limit') if event.get('limit') is not None else -1,appIdsAvailable=event.get('available') if event.get('available') is not None else -1)
        elif kind=='certificates':self.update(certificates=event.get('certificates',[]),certificatesLoaded=True,certificateTeam=event.get('team_id',''),busy=False,scanning=False)
        elif kind=='certificate_revoked':self.update(removal={},certificateLimit=False,status='Zertifikat widerrufen. Zugehörige Apps erneut installieren.')
        elif kind=='developer_mode_revealed':self.update(busy=False,status='Entwicklermodus in den iPhone-Einstellungen aktivieren.')
        elif kind=='device_trusted':self.trustRejected=False;self.update(busy=False,usbTrustPending=False);self.refresh()
        elif kind=='app_removed':
            self.update(busy=False,scanning=False,removal={},status='App entfernt.',success=False)
            self.componentDevice=None;self.inspectDevice()
        elif kind=='devices':
            old=self.data['devices'];index=self.data['deviceIndex']
            selected=old[index].get('id') if old and index<len(old) else None
            devices=event.get('devices',[])
            for device in devices:device['label']=device.get('name','Apple-Gerät')+' · '+device['id'][-4:]
            index=next((i for i,d in enumerate(devices) if d.get('id')==selected),0)
            if devices and devices[index]['id']!=selected:self.update(installedApps=[],slotsUsed=-1,developerApps=[],lcPrepared=False,developerMode='unknown')
            pending_here=bool(self.pendingSetup and (not devices or devices[index]['id']==self.pendingSetup['device']))
            self.update(devices=devices,deviceIndex=index,busy=False,scanning=False,setupPending=pending_here)
            if devices:
                if devices[index].get('trusted') is False:
                    self.update(usbTrustPending=True)
                    if not self.trustRejected:self.trustDevice()
                elif devices[index]['id']!=self.componentDevice or time.monotonic()-self.componentTime>(3 if self.pendingSetup else 30):self.inspectDevice()
            else:
                self.trustRejected=False;self.update(usbTrustPending=False)
                self.componentDevice=None
                self.update(vpnState='unknown',lcState='unknown',directsidePresent=False,lcPrepared=False,slotsUsed=-1,developerApps=[],installedApps=[],developerMode='unknown')
        elif kind=='device_components':
            if self.data['devices'] and event.get('device_id')==self.data['devices'][self.data['deviceIndex']]['id']:
                self.componentDevice=event['device_id'];self.componentTime=time.monotonic()
                cached={app['id']:app for app in self.data['installedApps']}
                apps=[dict(app,icon=cached.get(app['id'],{}).get('icon',''),iconChecked=cached.get(app['id'],{}).get('iconChecked',False)) for app in event.get('apps',[])]
                mode=event.get('developer_mode')
                self.update(developerMode='enabled' if mode is True else 'disabled' if mode is False else 'unknown',vpnState='installed' if event.get('localdevvpn') else 'missing',lcState='installed' if event.get('livecontainer') else 'missing',directsidePresent=bool(event.get('directside')),slotsUsed=event.get('slots_used',-1),developerApps=event.get('developer_apps',[]),installedApps=apps,busy=False,scanning=False)
                self.resumeSetup()
        elif kind=='app_icons':
            if self.data['devices'] and event.get('device_id')==self.data['devices'][self.data['deviceIndex']]['id']:
                icons={icon['id']:icon.get('png','') for icon in event.get('icons',[])}
                apps=[dict(app,icon=('data:image/png;base64,'+icons[app['id']]) if icons[app['id']] else '',iconChecked=True) if app['id'] in icons else app for app in self.data['installedApps']]
                self.update(installedApps=apps,busy=False,scanning=False)
        elif kind=='livecontainer_prepared':self.update(busy=self.installing,lcPrepared=True,status='DirectSide auf dem iPhone öffnen. Das Zertifikat wird automatisch an LiveContainer übergeben.')
        elif kind=='status':
            message=event.get('message','')
            self.update(status=message,**({'settingUp':True,'setupPhase':message} if event.get('phase')=='device_setup' else {}));self.append_log(message)
        elif kind=='progress':self.update(progress=event.get('value',0))
        elif kind=='two_factor':self.update(challenge='code',busy=True,numbers=event.get('numbers',[]),challengeError='Code nicht akzeptiert' if event.get('last_error') else '')
        elif kind=='choose_team':self.update(challenge='team',busy=True,teams=event.get('teams',[]))
        elif kind=='pairing_pin':self.update(challenge='pairing',busy=True)
        elif kind=='error':
            if event.get('command')=='trust_device':
                self.trustRejected=True;self.update(busy=False,scanning=False,usbTrustPending=True);return
            if event.get('command')=='app_ids':
                self.update(appIdsLoading=False,appIdsError='App-Kennungen konnten nicht geladen werden. Bitte erneut versuchen.');return
            if event.get('command')=='app_icons':
                apps=[dict(app,iconChecked=True) if app['id'] in getattr(self,'requestedIcons',[]) else app for app in self.data['installedApps']]
                self.update(busy=False,scanning=False,installedApps=apps)
                self.append_log('App-Icons konnten nicht geladen werden.');return
            if event.get('command')=='device_components':
                self.componentDevice=None
                self.update(busy=False,scanning=False,vpnState='unknown',lcState='unknown',directsidePresent=False,slotsUsed=-1,developerApps=[],installedApps=[])
                self.append_log('App-Prüfung nicht möglich. iPhone entsperren und Vertrauen bestätigen.');return
            self.fail(event.get('message','Unbekannter Fehler'))
            if '7460' in event.get('message',''):
                self.update(certificateLimit=True,error='Signierzertifikatlimit erreicht. Zertifikate verwalten.')
            if event.get('command')=='login' and 'Auth error -80046:' in event.get('message',''):
                self.update(loggedIn=False,authState='rejected',error='Apple verweigert die lokale Anmeldung (−80046).',status='Anmeldung erforderlich')
            if event.get('command')=='local_auth_probe' and self.initializing:self.initializing=False;self.refresh()
        elif kind=='installed':
            self.installing=False
            if event.get('developer_mode_required'):
                self.pendingSetup={'device':event['device_id'],'path':event['path'],'mode':self.data['signingMode'],'email':self.data['email']}
                self.setupRecord.parent.mkdir(parents=True,exist_ok=True)
                self.setupRecord.write_text(json.dumps(self.pendingSetup),encoding='utf-8')
                self.update(busy=False,success=False,progress=100,status='Entwicklermodus aktivieren',challenge='',directsideInstalling=False,settingUp=False,setupPhase='',setupPending=True,setupReady=False)
            else:self.update(busy=False,success=True,progress=100,status='Installiert',challenge='',directsideInstalling=False,settingUp=False,setupPhase='',setupReady=self.setupWasFirstInstall and bool(event.get('bootstrap_ready')))
            self.inspectDevice()
        elif kind=='directside_repaired':
            self.pendingSetup=None;self.setupRecord.unlink(missing_ok=True)
            self.update(busy=False,success=True,progress=100,settingUp=False,setupPhase='',setupPending=False,setupReady=True,status='DirectSide auf dem iPhone öffnen.')
            self.inspectDevice()

    def resumeSetup(self):
        pending=self.pendingSetup
        if not pending or self.data['busy'] or self.data['developerMode']!='enabled' or not self.data['devices']:return
        if self.data['devices'][self.data['deviceIndex']]['id']!=pending['device']:return
        if pending['mode']=='account' and (not self.data['loggedIn'] or self.data['email'].casefold()!=pending['email'].casefold()):return
        if pending['mode']=='imported' and not self.data['importedIdentity'].get('name'):return
        if not Path(pending['path']).is_file():self.update(error='Original-IPA auswählen.');return
        self.update(busy=True,settingUp=True,setupPhase='Einrichtung abschließen …',error='')
        self.send({'command':'repair_directside','signing_mode':pending['mode'],'device_id':pending['device'],'path':pending['path']})

    @Slot()
    def acknowledgeSetup(self):self.update(setupReady=False)

    @Slot()
    def trustDevice(self):
        if self.data['busy'] or not self.data['devices']:return
        self.trustRejected=False
        self.update(busy=True,scanning=False,usbTrustPending=True)
        self.send({'command':'trust_device','device_id':self.data['devices'][self.data['deviceIndex']]['id']})

    @Slot(result=bool)
    def loadAppIds(self):
        if not self.data['loggedIn']:return False
        if self.data['appIdsLoading']:return True
        self.update(appIdsLoading=True,appIdsError='')
        self.send({'command':'app_ids'})
        return True

    def persist(self,email):
        try:self.preferences.save(email,self.data['language']);self.data['savedEmail']=email.strip();return True
        except OSError:self.fail('Account-Einstellungen konnten nicht gespeichert werden.');return False

    @Slot(str,str,result=bool)
    def login(self,email,password):
        if not email.strip() or not password:self.fail('Apple-ID und Passwort eingeben.');return False
        if self.data['busy']:
            if not self.data['scanning']:return False
            self.pendingLogin=(email,password)
            self.update(authState='signing_in',status='Bei Apple anmelden …')
            return True
        if not self.persist(email):return False
        self.update(email=email.strip(),loggedIn=False,authState='signing_in',appIdsLimit=-1,appIdsAvailable=-1,appIdsRegistered=-1,busy=True,scanning=False,error='',status='Bei Apple anmelden …',success=False)
        self.send({'command':'login','email':email.strip(),'password':password})
        return True

    @Slot()
    def logout(self):
        if not self.data['busy']:self.update(busy=True);self.send({'command':'logout'})

    @Slot()
    def refresh(self):
        if self.data['busy']:return
        self.componentDevice=None
        self.update(busy=True,scanning=True);self.send({'command':'devices'})

    def auto_refresh(self):
        if not self.initializing and not self.data['busy'] and self.pendingLogin is None:
            self.update(busy=True,scanning=True);self.send({'command':'devices'})

    @Slot(int)
    def selectDevice(self,index):
        if not self.data['busy'] and 0<=index<len(self.data['devices']):self.update(deviceIndex=index,lcPrepared=False,installedApps=[],removal={},developerMode='unknown');self.inspectDevice()

    @Slot()
    def loadCertificates(self):
        if self.data['busy'] or self.data['updateBusy'] or not self.data['loggedIn']:return
        self.update(busy=True,removal={});self.send({'command':'certificates'})

    @Slot(str)
    def setSigningMode(self,mode):
        if self.data['busy'] or mode not in ('account','imported'):return
        try:self.preferences.save(self.data['email'],self.data['language'],mode)
        except OSError:self.fail('Account-Einstellungen konnten nicht gespeichert werden.');return
        self.update(signingMode=mode)

    @Slot()
    def chooseIdentityCertificate(self):
        if self.data['busy']:return
        path,_=QFileDialog.getOpenFileName(None,translate('P12-Datei auswählen',self.data['language']),'','PKCS#12 (*.p12 *.pfx)')
        if path:self.update(identityP12=path)

    @Slot()
    def chooseIdentityProfiles(self):
        if self.data['busy']:return
        paths,_=QFileDialog.getOpenFileNames(None,translate('Profile auswählen',self.data['language']),'','Apple profiles (*.mobileprovision)')
        if paths:self.update(identityProfiles=paths)

    @Slot(str)
    def importIdentity(self,password):
        if self.data['busy'] or not self.data['identityP12'] or not self.data['identityProfiles']:return
        self.setSigningMode('imported')
        self.update(busy=True,error='',status='Zertifikat prüfen …')
        self.send({'command':'import_identity','p12_path':self.data['identityP12'],'profile_paths':self.data['identityProfiles'],'password':password})

    @Slot()
    def forgetIdentity(self):
        if self.data['busy']:return
        self.update(busy=True);self.send({'command':'forget_identity'})

    @Slot(str)
    def requestAppRemoval(self,bundle):
        if self.data['busy'] or self.data['updateBusy'] or self.data['directsideInstalling'] or not self.data['devices']:return
        app=next((app for app in self.data['installedApps'] if app['id']==bundle),None)
        if app and app.get('developer'):self.update(removal={'kind':'app','id':bundle,'name':app['name'],'device':self.data['devices'][self.data['deviceIndex']]['id']})

    @Slot(str)
    def requestCertificateRemoval(self,serial):
        if self.data['busy'] or self.data['updateBusy'] or self.data['directsideInstalling']:return
        cert=next((cert for cert in self.data['certificates'] if cert.get('serial')==serial),None)
        if cert:self.update(removal={'kind':'certificate','id':serial,'name':cert['name'],'team':self.data['certificateTeam']})

    @Slot()
    def cancelRemoval(self):self.update(removal={})

    @Slot()
    def confirmRemoval(self):
        if self.data['busy'] or self.data['updateBusy'] or self.data['directsideInstalling']:return
        removal=self.data['removal']
        if removal.get('kind')=='app':
            if not self.data['devices'] or self.data['devices'][self.data['deviceIndex']]['id']!=removal.get('device'):self.update(removal={});return
            payload={'command':'remove_app','device_id':removal['device'],'bundle_id':removal['id'],'confirmed':True}
        elif removal.get('kind')=='certificate':
            if removal.get('team')!=self.data['certificateTeam']:self.update(removal={});return
            payload={'command':'revoke_certificate','serial':removal['id'],'team_id':removal['team'],'confirmed':True}
        else:return
        self.update(busy=True,scanning=False,removal={},error='',success=False,status='Entfernen …');self.send(payload)

    @Slot('QVariantList')
    def loadAppIcons(self,bundles):
        if self.data['busy'] or self.pendingLogin is not None or not self.data['devices']:return
        wanted={app['id'] for app in self.data['installedApps'] if not app.get('iconChecked')}
        selected=[bundle for bundle in bundles if isinstance(bundle,str) and bundle in wanted][:12]
        if not selected:return
        self.requestedIcons=selected
        self.update(busy=True,scanning=True)
        self.send({'command':'app_icons','device_id':self.data['devices'][self.data['deviceIndex']]['id'],'bundles':selected})

    @Slot()
    def inspectDevice(self):
        if self.data['busy'] or self.pendingLogin is not None or not self.data['devices']:return
        self.update(busy=True,scanning=True,vpnState='unknown',lcState='unknown',directsidePresent=False,slotsUsed=-1,developerApps=[])
        self.send({'command':'device_components','device_id':self.data['devices'][self.data['deviceIndex']]['id']})

    @Slot()
    def revealDeveloperMode(self):
        if self.data['busy'] or not self.data['devices']:return
        self.update(busy=True,error='')
        self.send({'command':'reveal_developer_mode','device_id':self.data['devices'][self.data['deviceIndex']]['id']})

    @Slot()
    def installLiveContainer(self):
        if self.data['busy'] or not self.data['canSign'] or not self.data['devices']:return
        self.update(busy=True,setupBusy=True,error='',progress=0,status='LiveContainer vorbereiten …')
        self.lcDevice=self.data['devices'][self.data['deviceIndex']]['id']
        def worker():
            try:download_livecontainer(self.setupEvent.emit)
            except Exception as error:self.setupEvent.emit({'type':'error','message':str(error)})
        threading.Thread(target=worker,daemon=True).start()

    @Slot()
    def prepareLiveContainer(self):
        if self.data['busy'] or not self.data['canSign'] or self.data['lcState']!='installed' or not self.data['directsidePresent']:return
        self.update(busy=True,error='',lcPrepared=False,status='Zertifikat lokal übertragen …')
        self.send({'command':'prepare_livecontainer','signing_mode':self.data['signingMode'],'device_id':self.data['devices'][self.data['deviceIndex']]['id']})

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
        if self.data['busy'] or self.data['updateBusy'] or self.data['directsideInstalling']:return
        path,_=QFileDialog.getOpenFileName(None,translate('IPA auswählen',self.data['language']),str(HOME),'iPhone app (*.ipa)')
        if path:self.update(ipa=path,ipaName=Path(path).name,customIPA=path,customIPAName=Path(path).name,ipaSource='file',success=False,error='')

    @Slot()
    def installCustomIPA(self):
        if self.data['busy'] or self.data['updateBusy'] or self.data['directsideInstalling'] or not self.data['customIPA']:return
        self.update(ipa=self.data['customIPA'],ipaName=self.data['customIPAName'],ipaSource='file')
        self.install()

    def releaseWorker(self,operation):
        self.update(updateBusy=True,updateProgress=0,updateMessage='')
        def work():
            try:operation()
            except Exception as error:
                # No URL, signed CDN query, token or network response enters Activity.
                message=str(error) if isinstance(error,UpdateError) else 'GitHub-Anfrage fehlgeschlagen. Erneut versuchen.'
                self.releaseEvent.emit({'type':'error','message':message})
        threading.Thread(target=work,daemon=True).start()

    @Slot()
    def checkUpdates(self):
        if self.data['updateBusy']:return
        def work():
            release=self.releaseClient.latest()
            self.releaseEvent.emit({'type':'release','release':release})
        self.releaseWorker(work)

    @Slot(str)
    def saveGitHub(self,token):
        if self.data['updateBusy']:return
        try:self.releaseClient.save_token(token.strip())
        except Exception:self.update(updateState='error',updateMessage='GitHub-Zugang konnte nicht gespeichert werden.');return
        self.update(githubSaved=True)
        self.checkUpdates()

    @Slot()
    def forgetGitHub(self):
        if self.data['updateBusy']:return
        try:self.releaseClient.forget_token()
        except OSError:self.update(updateState='error',updateMessage='GitHub-Zugang konnte nicht entfernt werden.');return
        self.release=None
        self.update(githubSaved=False,windowsUpdate=False,releaseIPA=False,releaseVersion='',updateState='unchecked',updateMessage='')

    @Slot()
    def downloadDirectSide(self):
        if self.data['updateBusy'] or (self.data['busy'] and not self.data['scanning']) or self.data['directsideInstalling'] or not self.data['canSign'] or not self.data['devices'] or not self.release or not self.data['releaseIPA']:return
        device=self.data['devices'][self.data['deviceIndex']]['id']
        self.update(directsideInstalling=True)
        def work():
            release=self.releaseClient.latest()
            if release is None:
                self.releaseEvent.emit({'type':'release','release':None});return
            path=self.releaseClient.download(release,'DirectSide.ipa',lambda value:self.releaseEvent.emit({'type':'progress','value':value}))
            self.releaseEvent.emit({'type':'release','release':release,'downloading':True})
            self.releaseEvent.emit({'type':'ipa','path':str(path),'version':release['tag_name'],'install_device':device})
        self.releaseWorker(work)

    def startPendingReleaseInstall(self):
        if self.pendingReleaseInstall is None or self.data['busy'] or self.pendingLogin:return
        path,device=self.pendingReleaseInstall;self.pendingReleaseInstall=None
        if not self.data['canSign'] or not self.data['devices'] or self.data['devices'][self.data['deviceIndex']]['id']!=device:
            self.fail('Zielgerät oder Anmeldung hat sich geändert. Installation erneut starten.');return
        self.data.update(ipa=path,ipaSource='github')
        self.install()

    @Slot()
    def updateWindows(self):
        if self.data['updateBusy'] or self.data['directsideInstalling'] or (self.data['busy'] and not self.data['scanning']) or self.pendingLogin or not self.release or not self.data['windowsUpdate']:return
        if not getattr(sys,'frozen',False):
            self.update(updateState='error',updateMessage='Windows-Updates sind in der gepackten EXE verfügbar.');return
        def work():
            release=self.releaseClient.latest()
            if release is None or version(release['tag_name'])<=version(VERSION):
                self.releaseEvent.emit({'type':'release','release':release});return
            path=self.releaseClient.download(release,'DirectSide.exe',lambda value:self.releaseEvent.emit({'type':'progress','value':value}))
            self.releaseEvent.emit({'type':'windows','path':str(path),'digest':digest(path)})
        self.releaseWorker(work)

    @Slot(dict)
    def onReleaseEvent(self,event):
        kind=event['type']
        if kind=='progress':self.update(updateProgress=event['value']);return
        if kind=='release':
            self.release=event['release']
            if not self.release:
                self.update(updateBusy=False,directsideInstalling=False,updateState='empty',updateMessage='Noch keine Version freigegeben.',releaseVersion='',windowsUpdate=False,releaseIPA=False);return
            assets={a.get('name') for a in self.release.get('assets',[])}
            newer=version(self.release['tag_name'])>version(VERSION)
            self.update(updateBusy=event.get('downloading',False),updateState='available' if newer else 'current',updateMessage='',releaseVersion=self.release['tag_name'],windowsUpdate=newer and 'DirectSide.exe' in assets,releaseIPA='DirectSide.ipa' in assets)
        elif kind=='ipa':
            if event.get('install_device'):self.pendingReleaseInstall=(event['path'],event['install_device'])
            self.update(updateBusy=False,ipa=event['path'],ipaName='DirectSide · '+event['version'],ipaSource='github',success=False,error='',updateMessage='' if event.get('install_device') else 'DirectSide-IPA bereit.')
        elif kind=='error':self.update(updateBusy=False,directsideInstalling=False,updateState='error',updateMessage=event['message'])
        elif kind=='windows':
            # A login or installation may have started during the download. Defer restart.
            if (self.data['busy'] and not self.data['scanning']) or self.pendingLogin or self.data['directsideInstalling']:
                self.update(updateBusy=False,updateMessage='Update bereit. Nach dem aktuellen Vorgang erneut auf Aktualisieren klicken.');return
            try:
                import subprocess
                subprocess.Popen([event['path'],'--apply-update',str(os.getpid()),sys.executable,event['digest']],close_fds=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            except OSError:
                self.update(updateBusy=False,updateState='error',updateMessage='Windows-Updater konnte nicht gestartet werden.');return
            QApplication.instance().quit()

    @Slot()
    def install(self):
        if self.data['busy'] or self.data['updateBusy'] or not self.data['canSign'] or not self.data['devices']:return
        path=Path(self.data['ipa'])
        try:bundle=ipa_identity(path)
        except Exception:self.fail('Keine gültige IPA ausgewählt.');return
        self.installing=True
        self.setupWasFirstInstall=bundle=='com.directside.app' and not self.data['directsidePresent']
        self.update(busy=True,progress=0,error='',success=False,status='Installation vorbereiten …')
        self.send({'command':'install','signing_mode':self.data['signingMode'],'device_id':self.data['devices'][self.data['deviceIndex']]['id'],'path':str(path),'bundle_id':bundle,'bootstrap':bundle=='com.directside.app'})

    @Slot()
    def dismissError(self):self.update(error='')

    @Slot(result=bool)
    def repairDirectSide(self):
        if self.data['busy'] or self.data['updateBusy'] or not self.data['devices']:return False
        if not self.data['canSign']:self.fail('Bitte anmelden oder ein Zertifikat importieren.');return False
        paths=[Path(self.data['ipa']),HOME/'DirectSide.ipa',ROOT/'dist'/'DirectSide.ipa']
        for path in paths:
            try:
                if ipa_identity(path)=='com.directside.app':break
            except Exception:pass
        else:self.fail('Für die Einrichtung bitte die DirectSide-IPA auswählen.');return False
        self.update(busy=True,settingUp=True,setupPhase='Geräteinformationen für die Kopplung lesen …',error='',success=False)
        self.send({'command':'repair_directside','signing_mode':self.data['signingMode'],'device_id':self.data['devices'][self.data['deviceIndex']]['id'],'path':str(path)})
        return True

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
            self.send({'command':'install','signing_mode':self.data['signingMode'],'device_id':self.lcDevice,'path':str(path),'bundle_id':bundle,'bootstrap':False})
        elif kind=='done':
            self.update(busy=False,setupBusy=False,usbState=usb_status(),status=event.get('message',''),progress=0)
            self.checkComponents()

    def exited(self,*_):
        if self.process.state()==QProcess.NotRunning:self.fail('Signierkern beendet. DirectSide neu starten.')

    def close(self):
        self.pendingLogin=None
        self.pendingReleaseInstall=None
        self.timer.stop()
        self.updateTimer.stop()
        if self.process.state()!=QProcess.NotRunning:self.process.terminate();self.process.waitForFinished(1500)


def main():
    os.environ['DIRECTSIDE_LOCAL_HELPER']=json.dumps([sys.executable]+([] if getattr(sys,'frozen',False) else [str(ROOT/'ui/desktop.py')]))
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
