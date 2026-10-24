"""Qt UI tests use dummy protocol events and never contact Apple."""
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
from PySide6.QtCore import QUrl,Qt,QObject,QMetaObject
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from desktop import DesktopBridge
from common import Preferences,ROOT
APP=QApplication.instance() or QApplication([])
QQuickStyle.setStyle('Basic')
class WindowsUIStateTests(unittest.TestCase):
 def setUp(self):
  self.folder=tempfile.TemporaryDirectory()
  self.bridge=DesktopBridge(start=False,preferences=Preferences(Path(self.folder.name)/'preferences.json'))
  self.sent=[];self.bridge.send=self.sent.append
 def tearDown(self):self.bridge.timer.stop();self.folder.cleanup()
 def test_code_validation_and_cancel_stay_inline(self):
  self.bridge.handle({'event':'two_factor'})
  self.bridge.submitCode('123');self.assertEqual(self.sent,[])
  self.assertTrue(self.bridge.data['challengeError'])
  self.bridge.submitCode('012345')
  self.assertEqual(self.sent,[{'action':'code','code':'012345'}])
  self.assertEqual(self.bridge.data['challenge'],'')
 def test_restore_serializes_commands_and_saves_identity(self):
  self.bridge.handle({'event':'ready'})
  self.assertEqual(self.sent,[{'command':'local_auth_probe'}])
  self.bridge.handle({'event':'local_auth_ready'})
  self.assertEqual(self.sent[-1],{'command':'restore'})
  self.bridge.handle({'event':'logged_in','email':'person@example.com','team':'Test'})
  self.assertEqual(self.sent[-1],{'command':'devices'})
  self.assertEqual(self.bridge.preferences.load()['email'],'person@example.com')
 def test_auto_login_progress_is_in_account_card_until_session_is_validated(self):
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  progress=root.findChild(QObject,'accountAuthProgress');label=root.findChild(QObject,'accountAuthProgressText')
  email=root.findChild(QObject,'emailField')
  APP.processEvents()
  self.assertTrue(progress.property('visible'));self.assertFalse(email.property('visible'))
  self.assertEqual(label.property('text'),'Signing in automatically …')
  self.bridge.handle({'event':'local_auth_ready'});APP.processEvents()
  self.assertTrue(progress.property('visible'));self.assertFalse(self.bridge.data['loggedIn'])
  self.bridge.handle({'event':'logged_out','reason':'expired'});APP.processEvents()
  self.assertFalse(progress.property('visible'));self.assertTrue(email.property('visible'))
  self.assertTrue(root.findChild(QObject,'accountSessionExpired').property('visible'))
  self.bridge.update(authState='signing_in',busy=True);APP.processEvents()
  self.assertTrue(progress.property('visible'));self.assertEqual(label.property('text'),'Signing in to Apple …')
  self.bridge.handle({'event':'logged_in','team':'Personal team','email':'fixture@example.com'});APP.processEvents()
  self.assertFalse(progress.property('visible'));self.assertFalse(email.property('visible'))
  root.close();engine.deleteLater();APP.processEvents()

 def test_certificate_count_is_separate_from_app_slots_and_pagination_recovers(self):
  self.bridge.initializing=False
  self.bridge.update(busy=False,loggedIn=True,authState='signed_in',team='Personal team',devices=[{'id':'phone','label':'Test phone'}],slotsUsed=3)
  self.bridge.handle({'event':'certificates','team_id':'team','certificates':[{'serial':str(i),'name':'Certificate','platform':'unified'} for i in range(4)]})
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0];root.setProperty('page','certificates')
  root.setProperty('certificatePage',1);APP.processEvents()
  self.bridge.handle({'event':'certificates','team_id':'team','certificates':[{'serial':'one','name':'Certificate','platform':'unified'}]});APP.processEvents()
  self.assertEqual(root.property('certificatePage'),0)
  self.assertEqual(root.findChild(QObject,'certificateCountBadge').property('text'),'Certificates · 1')
  button=root.findChild(QObject,'manageDeviceAppsButton')
  self.assertEqual(button.property('text'),'Apps on this device · 3 / 3')
  QMetaObject.invokeMethod(button,'clicked');APP.processEvents()
  self.assertEqual(root.property('page'),'apps');self.assertTrue(root.property('developerOnly'))
  self.assertTrue(any(request.get('command')=='device_components' for request in self.sent))
  root.close();engine.deleteLater();APP.processEvents()
 def test_usb_selection_survives_reordering(self):
  self.bridge.update(devices=[{'id':'A'},{'id':'B'}],deviceIndex=1)
  self.bridge.handle({'event':'devices','devices':[{'id':'B'},{'id':'A'}]})
  self.assertEqual(self.bridge.data['deviceIndex'],0)
 def test_success_and_failure_are_inline(self):
  self.bridge.handle({'event':'installed'});self.assertTrue(self.bridge.data['success'])
  self.bridge.handle({'event':'error','message':'Test error'})
  self.assertEqual(self.bridge.data['error'],'Test error');self.assertFalse(self.bridge.data['busy'])
 def test_connected_device_is_polled_without_refresh_click(self):
  self.bridge.initializing=False;self.bridge.update(busy=False,devices=[{'id':'phone'}])
  self.bridge.auto_refresh()
  self.assertEqual(self.sent[-1],{'command':'devices'})
 def test_app_status_and_slots_belong_to_selected_device(self):
  self.bridge.update(busy=False,devices=[{'id':'phone'},{'id':'tablet'}])
  self.bridge.handle({'event':'device_components','device_id':'phone','localdevvpn':True,'livecontainer':True,'slots_used':3,'developer_apps':[{'name':'DirectSide'},{'name':'EUP Dev'},{'name':'EUP Test'}]})
  self.assertEqual(self.bridge.data['slotsUsed'],3)
  self.bridge.selectDevice(1)
  self.assertEqual(self.sent[-1],{'command':'device_components','device_id':'tablet'})
  self.assertEqual(self.bridge.data['slotsUsed'],-1)
  self.bridge.handle({'event':'device_components','device_id':'phone','slots_used':3})
  self.assertEqual(self.bridge.data['slotsUsed'],-1)
  self.bridge.handle({'event':'device_components','device_id':'tablet','localdevvpn':False,'slots_used':1,'developer_apps':[{'name':'DirectSide'}]})
  self.assertEqual(self.bridge.data['slotsUsed'],1)
  self.assertEqual(self.bridge.data['vpnState'],'missing')
 def test_failed_or_disconnected_probe_is_not_reported_as_missing(self):
  self.bridge.update(vpnState='installed',slotsUsed=3)
  self.bridge.handle({'event':'error','command':'device_components'})
  self.assertEqual(self.bridge.data['vpnState'],'unknown');self.assertEqual(self.bridge.data['slotsUsed'],-1)
  self.bridge.handle({'event':'devices','devices':[]})
  self.assertEqual(self.bridge.data['developerApps'],[])
 def test_icons_are_loaded_only_for_selected_device_and_cached(self):
  self.bridge.update(busy=False,devices=[{'id':'tablet'}],installedApps=[{'id':'eup','name':'EUP Test','icon':'','iconChecked':False}])
  self.bridge.loadAppIcons(['eup'])
  self.assertEqual(self.sent[-1],{'command':'app_icons','device_id':'tablet','bundles':['eup']})
  self.bridge.handle({'event':'app_icons','device_id':'phone','icons':[{'id':'eup','png':'wrong'}]})
  self.assertEqual(self.bridge.data['installedApps'][0]['icon'],'')
  self.bridge.handle({'event':'app_icons','device_id':'tablet','icons':[{'id':'eup','png':'fixture'}]})
  self.assertEqual(self.bridge.data['installedApps'][0]['icon'],'data:image/png;base64,fixture')
  count=len(self.sent);self.bridge.loadAppIcons(['eup']);self.assertEqual(len(self.sent),count)
 def test_language_defaults_to_english_and_persists_with_account(self):
  self.assertEqual(self.bridge.data['language'],'en')
  self.bridge.update(status='Bereit');self.assertEqual(self.bridge.data['status'],'Ready')
  self.bridge.setLanguage('de');self.assertEqual(self.bridge.data['status'],'Bereit')
  self.bridge.persist('person@example.com')
  restored=DesktopBridge(start=False,preferences=self.bridge.preferences)
  self.assertEqual(restored.data['language'],'de')
  self.assertEqual(restored.data['email'],'person@example.com')
 def test_qml_loads_at_minimum_size_without_native_frame(self):
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')))
  self.assertEqual(len(engine.rootObjects()),1)
  root=engine.rootObjects()[0];root.setWidth(960);root.setHeight(680)
  APP.processEvents();self.assertTrue(root.flags() & Qt.FramelessWindowHint)
  root.close();engine.deleteLater();APP.processEvents()

 def test_email_draft_survives_poll_and_login_waits_for_scan(self):
  self.bridge.initializing=False;self.bridge.update(busy=False,authState='expired')
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  email=root.findChild(QObject,'emailField');password=root.findChild(QObject,'passwordField');button=root.findChild(QObject,'loginButton')
  email.setProperty('text','person@example.com');QMetaObject.invokeMethod(email,'textEdited')
  password.setProperty('text','fixture-password')
  self.bridge.auto_refresh();APP.processEvents()
  self.assertEqual(email.property('text'),'person@example.com')
  self.assertTrue(email.property('enabled'));self.assertTrue(button.property('enabled'))
  QMetaObject.invokeMethod(button,'clicked');APP.processEvents()
  self.assertEqual(password.property('text'),'')
  self.assertEqual([r['command'] for r in self.sent],['devices'])
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','name':'Test phone'}]});APP.processEvents()
  self.assertEqual([r['command'] for r in self.sent],['devices','login'])
  self.assertEqual(self.sent[-1]['email'],'person@example.com')
  self.assertIsNone(self.bridge.pendingLogin)
  self.assertFalse(email.property('enabled'))
  root.close();engine.deleteLater();APP.processEvents()

 def test_expired_session_and_real_registration_allowance(self):
  self.bridge.handle({'event':'logged_out','reason':'expired'})
  self.assertFalse(self.bridge.data['loggedIn']);self.assertEqual(self.bridge.data['authState'],'expired')
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.handle({'event':'account_quota','limit':10,'available':3,'registered':1});APP.processEvents()
  badge=root.findChild(QObject,'quotaBadge')
  self.assertEqual(badge.property('text'),'App IDs · 7 / 10 used · 3 left')
  self.assertEqual(badge.property('tone'),'warning')
  self.bridge.handle({'event':'account_quota','limit':10,'available':0,'registered':1});APP.processEvents()
  self.assertEqual(badge.property('tone'),'missing')
  self.bridge.handle({'event':'account_quota','limit':10,'available':8,'registered':1});APP.processEvents()
  self.assertEqual(badge.property('tone'),'ok')
  self.bridge.handle({'event':'logged_out'});APP.processEvents()
  self.assertEqual(self.bridge.data['appIdsAvailable'],-1)
  root.close();engine.deleteLater();APP.processEvents()
 def test_rejected_token_does_not_claim_successful_sign_in(self):
  self.bridge.update(authState='signing_in',busy=True)
  message='Failed to get xcode token\nAuth error -80046: This action cannot be completed at this time.'
  self.bridge.handle({'event':'error','command':'login','message':message})
  self.assertFalse(self.bridge.data['loggedIn']);self.assertFalse(self.bridge.data['busy'])
  self.assertEqual(self.bridge.data['authState'],'rejected')
  self.assertEqual(self.bridge.data['error'],'Apple rejected local sign-in (−80046).')
  self.assertIn(message,self.bridge.data['logs'])

 def test_release_state_preserves_own_ipa_and_does_not_claim_unreleased_update(self):
  self.bridge.update(ipa='custom.ipa',ipaName='Custom app',ipaSource='file')
  self.bridge.onReleaseEvent({'type':'release','release':None})
  self.assertEqual(self.bridge.data['updateState'],'empty')
  self.assertFalse(self.bridge.data['windowsUpdate'])
  self.assertEqual(self.bridge.data['ipa'],'custom.ipa')
  self.bridge.onReleaseEvent({'type':'release','release':{'tag_name':'v0.2.0','assets':[{'name':'DirectSide.exe'},{'name':'DirectSide.ipa'}]}})
  self.assertTrue(self.bridge.data['windowsUpdate']);self.assertTrue(self.bridge.data['releaseIPA'])
  self.assertEqual(self.bridge.data['ipa'],'custom.ipa')
  self.bridge.onReleaseEvent({'type':'ipa','path':'download.ipa','version':'v0.2.0'})
  self.assertEqual(self.bridge.data['ipaSource'],'github')
  self.assertEqual(self.bridge.data['ipa'],'download.ipa')

 def test_restart_is_deferred_if_authentication_started_while_downloading(self):
  self.bridge.update(busy=True,scanning=False,updateBusy=True)
  self.bridge.onReleaseEvent({'type':'windows','path':'must-not-run.exe','digest':'fake'})
  self.assertFalse(self.bridge.data['updateBusy'])
  self.assertIn('Update bereit',self.bridge.data['updateMessage'])

 def test_github_and_other_ipa_controls_fit_update_settings_at_minimum_size(self):
  self.bridge.update(busy=False,updateState='available',windowsUpdate=True,releaseVersion='v0.2.0',releaseIPA=True)
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')))
  root=engine.rootObjects()[0];root.setWidth(960);root.setHeight(680)
  root.setProperty('page','settings');root.setProperty('settingsSection','updates');APP.processEvents()
  self.assertEqual(root.property('settingsSection'),'updates')
  self.assertEqual(root.findChild(QObject,'installDirectSideButton').property('text'),'Install DirectSide')
  self.assertEqual(root.findChild(QObject,'ipaVersionBadge').property('text'),'v0.2.0')
  self.assertEqual(len(root.findChildren(QObject,'windowsUpdateButton')),1)
  root.close();engine.deleteLater();APP.processEvents()

 def test_directside_one_click_install_waits_for_usb_scan_and_keeps_custom_ipa(self):
  import plistlib,zipfile
  ipa=Path(self.folder.name)/'DirectSide.ipa'
  with zipfile.ZipFile(ipa,'w') as archive:archive.writestr('Payload/DirectSide.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'com.directside.app'}))
  self.bridge.update(busy=True,scanning=True,loggedIn=True,devices=[{'id':'phone'}],directsideInstalling=True,customIPA='other.ipa',customIPAName='Other app')
  self.bridge.onReleaseEvent({'type':'ipa','path':str(ipa),'version':'v0.2.0','install_device':'phone'})
  self.assertEqual(self.sent,[])
  self.assertIsNotNone(self.bridge.pendingReleaseInstall)
  self.bridge.update(busy=False,scanning=False)
  self.bridge.startPendingReleaseInstall();APP.processEvents()
  self.assertEqual(len(self.sent),1)
  self.assertEqual(self.sent[0]['command'],'install')
  self.assertEqual(self.sent[0]['device_id'],'phone')
  self.assertEqual(self.sent[0]['bundle_id'],'com.directside.app')
  self.assertTrue(self.sent[0]['bootstrap'])
  self.assertEqual(self.bridge.data['customIPA'],'other.ipa')

 def test_directside_download_does_not_install_on_a_different_device(self):
  self.bridge.update(busy=True,loggedIn=True,devices=[{'id':'tablet'}],directsideInstalling=True)
  self.bridge.onReleaseEvent({'type':'ipa','path':'DirectSide.ipa','version':'v0.2.0','install_device':'phone'})
  self.bridge.update(busy=False)
  self.bridge.startPendingReleaseInstall();APP.processEvents()
  self.assertEqual(self.sent,[])
  self.assertFalse(self.bridge.data['directsideInstalling'])
  self.assertTrue(self.bridge.data['error'])

 def test_install_controls_stay_inside_card_at_minimum_size(self):
  from PySide6.QtCore import QPointF
  from PySide6.QtGui import QFont,QFontDatabase
  QFontDatabase.addApplicationFont('C:/Windows/Fonts/segoeui.ttf')
  self.bridge.update(busy=False,loggedIn=True,devices=[{'id':'phone','label':'iPhone'}],releaseIPA=True,releaseVersion='v0.2.0')
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')))
  root=engine.rootObjects()[0];root.setProperty('font',QFont('Segoe UI',10));root.setWidth(960);root.setHeight(680)
  card=root.findChild(QObject,'installCard');row=root.findChild(QObject,'customIPARow')
  for language in ('en','de'):
   for vpn in ('missing','installed'):
    self.bridge.update(language=language,vpnState=vpn)
    for _ in range(4):APP.processEvents()
    top=card.mapToScene(QPointF(0,0));position=row.mapToScene(QPointF(0,0))
    self.assertLessEqual(position.y()+row.height(),top.y()+card.height()-20)
    self.assertLessEqual(position.x()+row.width(),top.x()+card.width()-20)
  root.close();engine.deleteLater();APP.processEvents()

 def test_app_removal_needs_confirmation_and_remains_device_scoped(self):
  self.bridge.update(busy=False,devices=[{'id':'phone'},{'id':'tablet'}],installedApps=[{'id':'third.party.app','name':'Other installer app'}])
  self.bridge.requestAppRemoval('third.party.app');self.assertEqual(self.sent,[])
  self.bridge.update(deviceIndex=1)
  self.bridge.confirmRemoval();self.assertEqual(self.sent,[])
  self.bridge.update(deviceIndex=0)
  self.bridge.requestAppRemoval('third.party.app');self.bridge.confirmRemoval()
  self.assertEqual(self.sent,[{'command':'remove_app','device_id':'phone','bundle_id':'third.party.app','confirmed':True}])

 def test_certificate_removal_is_explicit_and_not_app_slot_removal(self):
  self.bridge.update(busy=False,loggedIn=True)
  self.bridge.handle({'event':'certificates','team_id':'personal-team','certificates':[{'serial':'ABC','name':'Old installer','reusable':False}]})
  self.bridge.requestCertificateRemoval('ABC');self.assertEqual(self.sent,[])
  self.bridge.cancelRemoval();self.bridge.confirmRemoval();self.assertEqual(self.sent,[])
  self.bridge.requestCertificateRemoval('ABC');self.bridge.confirmRemoval()
  self.assertEqual(self.sent,[{'command':'revoke_certificate','serial':'ABC','team_id':'personal-team','confirmed':True}])

 def test_7460_opens_certificate_management_and_never_revokes_automatically(self):
  self.bridge.update(busy=True,loggedIn=True)
  self.bridge.handle({'event':'error','command':'install','message':'Developer error 7460: Maximum number of certificates reached'})
  self.assertTrue(self.bridge.data['certificateLimit'])
  self.assertEqual(self.sent,[])
  self.assertIn('Signing certificate limit',self.bridge.data['error'])

 def test_setup_repair_requires_login_to_transfer_signing_identity_without_reinstalling(self):
  import zipfile,plistlib
  ipa=Path(self.folder.name)/'DirectSide.ipa'
  with zipfile.ZipFile(ipa,'w') as archive:archive.writestr('Payload/DirectSide.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'com.directside.app'}))
  self.bridge.update(busy=False,loggedIn=False,devices=[{'id':'phone'},{'id':'tablet'}],deviceIndex=1,ipa=str(ipa))
  self.assertFalse(self.bridge.repairDirectSide());self.assertEqual(self.sent,[])
  self.bridge.update(loggedIn=True)
  self.assertTrue(self.bridge.repairDirectSide())
  self.assertEqual(self.sent,[{'command':'repair_directside','device_id':'tablet','path':str(ipa)}])
  self.assertTrue(self.bridge.data['settingUp']);self.assertEqual(self.bridge.data['challenge'],'')
  self.assertFalse(self.bridge.repairDirectSide());self.assertEqual(len(self.sent),1)

 def test_usb_pairing_progress_is_visible_without_a_code_challenge_and_clears_on_error(self):
  self.bridge.update(busy=True,vpnState='missing')
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.handle({'event':'status','phase':'device_setup','message':'USB-Kopplung automatisch bestätigen …'});APP.processEvents()
  self.assertTrue(root.findChild(QObject,'deviceSetupProgress').property('visible'))
  self.assertFalse(root.findChild(QObject,'vpnInstallPrompt').property('visible'))
  self.assertEqual(self.bridge.data['challenge'],'')
  self.assertEqual(root.findChild(QObject,'deviceSetupProgressText').property('text'),'Completing USB pairing automatically …')
  self.bridge.handle({'event':'error','message':'Pairing timed out'});APP.processEvents()
  self.assertFalse(root.findChild(QObject,'deviceSetupProgress').property('visible'));self.assertFalse(self.bridge.data['settingUp'])
  root.close();engine.deleteLater();APP.processEvents()

 def test_developer_mode_guide_uses_device_status_and_never_enables_or_reboots(self):
  self.bridge.initializing=False
  self.bridge.update(busy=False,devices=[{'id':'phone','name':'iPhone','label':'iPhone'}])
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.handle({'event':'device_components','device_id':'phone','developer_mode':False});APP.processEvents()
  self.assertEqual(self.bridge.data['developerMode'],'disabled');self.assertEqual(root.property('page'),'developer')
  self.assertTrue(root.findChild(QObject,'developerModeGuide').property('visible'));self.assertEqual(self.sent,[])
  self.bridge.revealDeveloperMode();self.assertEqual(self.sent,[{'command':'reveal_developer_mode','device_id':'phone'}])
  self.bridge.handle({'event':'developer_mode_revealed','device_id':'phone'})
  self.bridge.handle({'event':'device_components','device_id':'phone','developer_mode':None});APP.processEvents()
  self.assertEqual(self.bridge.data['developerMode'],'unknown')
  self.bridge.handle({'event':'device_components','device_id':'phone','developer_mode':True});APP.processEvents()
  self.assertEqual(self.bridge.data['developerMode'],'enabled')
  self.bridge.handle({'event':'device_components','device_id':'other-phone','developer_mode':False})
  self.assertEqual(self.bridge.data['developerMode'],'enabled')
  root.close();engine.deleteLater();APP.processEvents()
if __name__=='__main__':unittest.main()
