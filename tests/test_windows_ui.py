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
 def test_expected_shutdown_does_not_report_engine_failure(self):
  self.bridge.update(error='')
  self.bridge.close();self.bridge.exited();self.bridge.processError()
  self.assertEqual(self.bridge.data['error'],'')
 def test_usb_loss_is_distinct_from_first_start_and_recovers(self):
  self.bridge.handle({'event':'devices','devices':[]})
  self.assertFalse(self.bridge.data['usbReconnectNeeded'])
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','trusted':True}]})
  self.bridge.handle({'event':'devices','devices':[]})
  self.assertTrue(self.bridge.data['usbReconnectNeeded'])
  self.bridge.handle({'event':'devices','devices':[]})
  self.assertTrue(self.bridge.data['usbReconnectNeeded'])
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','trusted':True}]})
  self.assertFalse(self.bridge.data['usbReconnectNeeded'])
  self.bridge.handle({'event':'error','command':'devices','message':'USB service unavailable'})
  self.assertTrue(self.bridge.data['usbReconnectNeeded']);self.assertEqual(self.bridge.data['devices'],[])
  self.assertFalse(self.bridge.data['error'])
 def test_usb_reconnect_guide_preserves_page_and_fits_small_window(self):
  from PySide6.QtCore import QPointF
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  root.setWidth(960);root.setHeight(680);root.setProperty('page','appids')
  self.bridge.update(usbReconnectNeeded=True,devices=[]);APP.processEvents()
  card=root.findChild(QObject,'usbReconnectCard');title=root.findChild(QObject,'usbReconnectTitle')
  self.assertTrue(card.property('visible'));self.assertEqual(root.property('page'),'reconnect')
  pulse=root.findChild(QObject,'usbReconnectPulse');self.assertTrue(pulse.property('running'))
  point=title.mapToScene(QPointF(0,0));self.assertGreater(point.y(),78)
  self.assertLess(point.y()+title.height(),620)
  self.bridge.update(usbReconnectNeeded=False);APP.processEvents()
  self.assertFalse(card.property('visible'));self.assertEqual(root.property('page'),'appids')
  self.assertFalse(pulse.property('running'))
  root.close();engine.deleteLater();APP.processEvents()
 def test_pending_setup_reconnect_hint_only_when_disconnected(self):
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  root.setProperty('page','developer')
  self.bridge.update(setupPending=True,devices=[]);APP.processEvents()
  hint=root.findChild(QObject,'setupReconnectHint');self.assertTrue(hint.property('visible'))
  self.bridge.update(devices=[{'id':'phone'}]);APP.processEvents();self.assertFalse(hint.property('visible'))
  root.close();engine.deleteLater();APP.processEvents()
 def test_developer_help_distinguishes_enabled_pending_disabled_and_unknown(self):
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.update(language='en',busy=False,developerMode='enabled',setupPending=False,setupReady=False,launchState='idle')
  root.setProperty('page','developer');APP.processEvents()
  title=root.findChild(QObject,'developerModeTitle');done=root.findChild(QObject,'developerModeDone')
  self.assertEqual(title.property('text'),'Developer Mode is enabled')
  self.assertTrue(root.property('developerSuccess'));self.assertEqual(done.property('text'),'Done')
  self.bridge.update(setupPending=True);APP.processEvents()
  self.assertEqual(title.property('text'),'Completing setup…')
  self.assertFalse(root.property('developerSuccess'));self.assertFalse(done.property('enabled'))
  self.bridge.update(setupPending=False,developerMode='disabled');APP.processEvents()
  self.assertEqual(title.property('text'),'Enable Developer Mode')
  self.assertFalse(root.property('developerSuccess'))
  self.bridge.update(developerMode='unknown');APP.processEvents()
  self.assertEqual(title.property('text'),'Check Developer Mode')
  self.assertFalse(root.property('developerSuccess'))
  root.close();engine.deleteLater();APP.processEvents()
 def test_setup_check_again_rediscovers_usb_and_poll_recovers_without_reinstall(self):
  self.bridge.initializing=False
  self.bridge.update(busy=False,setupPending=True,developerMode='disabled',devices=[])
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  root.setProperty('page','developer');APP.processEvents()
  button=root.findChild(QObject,'developerModeRefresh')
  self.assertTrue(button.property('enabled'))
  QMetaObject.invokeMethod(button,'clicked');APP.processEvents()
  self.assertEqual(self.sent[-1],{'command':'devices'})
  self.bridge.handle({'event':'devices','devices':[]})
  self.assertTrue(self.bridge.data['deviceCheckedAt'])
  self.bridge.auto_refresh();self.assertEqual(self.sent[-1],{'command':'devices'})
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','trusted':True}]})
  self.assertEqual(self.sent[-1],{'command':'device_components','device_id':'phone'})
  self.assertFalse(any(e['command']=='install' for e in self.sent))
  root.close();engine.deleteLater();APP.processEvents()
 def test_restore_serializes_commands_and_saves_identity(self):
  self.bridge.handle({'event':'ready'})
  self.assertEqual(self.sent,[{'command':'imported_identity'},{'command':'local_auth_probe'}])
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
  self.assertEqual(button.property('text'),'Apps on this device · 3 development apps')
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
 def test_logout_stays_enabled_during_poll_and_waits_for_scan_result(self):
  self.bridge.initializing=False;self.bridge.update(busy=False,loggedIn=True)
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.auto_refresh();APP.processEvents()
  button=root.findChild(QObject,'logoutButton');self.assertTrue(button.property('enabled'))
  self.bridge.logout();self.assertTrue(self.bridge.pendingLogout)
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','trusted':True}]});APP.processEvents()
  self.assertEqual([event['command'] for event in self.sent],['devices','logout'])
  self.assertFalse(button.property('enabled'))
  root.close();engine.deleteLater();APP.processEvents()
 def test_usb_recovery_acts_once_and_never_when_device_is_available(self):
  from unittest.mock import patch
  self.bridge.update(busy=False,usbReconnectNeeded=True,devices=[])
  with patch('desktop.threading.Thread') as worker:
   self.bridge.onSetupEvent({'type':'usb_pnp','count':2});worker.assert_not_called()
   self.bridge.onSetupEvent({'type':'usb_pnp','count':1});self.assertEqual(worker.call_count,1)
   self.bridge.onSetupEvent({'type':'usb_pnp','count':1});self.assertEqual(worker.call_count,1)
   self.bridge.onSetupEvent({'type':'usb_recovered','ok':False})
   self.assertEqual(self.sent[-1],{'command':'devices'})
   self.bridge.onSetupEvent({'type':'usb_pnp','count':1});self.assertEqual(worker.call_count,1)
  self.assertEqual(self.bridge.data['usbRepairState'],'failed')
 def test_launch_failure_keeps_setup_open_and_ignores_another_device(self):
  self.bridge.pendingSetup={'device':'phone','path':'fixture','mode':'account','email':'fixture@example.com','phase':'launch'}
  self.bridge.update(busy=False,devices=[{'id':'phone'}],launchState='checking')
  self.bridge.handle({'event':'directside_launch_result','device_id':'other','ok':True})
  self.assertFalse(self.bridge.data['setupReady'])
  self.bridge.handle({'event':'directside_launch_result','device_id':'phone','ok':False})
  self.assertFalse(self.bridge.data['success']);self.assertEqual(self.bridge.data['launchState'],'blocked')
  self.assertEqual(self.sent[-1],{'command':'open_trust_settings','device_id':'phone'})
  self.bridge.handle({'event':'trust_settings_opened','device_id':'phone','ok':True})
  self.assertFalse(self.bridge.data['setupReady'])
  self.bridge.update(developerMode='enabled');self.sent.clear();self.bridge.resumeSetup()
  self.assertEqual(self.sent,[]) # Do not repeatedly pull the user out of Settings.
 def test_buttons_stay_stable_and_actions_are_serialized_during_usb_scan(self):
  self.bridge.initializing=False;self.bridge.update(busy=False,loggedIn=True,devices=[{'id':'phone','trusted':True}])
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  root.setProperty('page','developer');APP.processEvents()
  button=root.findChild(QObject,'developerModeRefresh');before=(button.property('text'),button.property('opacity'),button.property('enabled'))
  self.bridge.auto_refresh();APP.processEvents()
  self.assertEqual((button.property('text'),button.property('opacity'),button.property('enabled')),before)
  self.bridge.revealDeveloperMode();self.bridge.revealDeveloperMode()
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','trusted':True}]});APP.processEvents()
  self.assertEqual([item['command'] for item in self.sent],['devices','reveal_developer_mode'])
  self.assertTrue(self.bridge.data['foregroundBusy'])
  root.close();engine.deleteLater();APP.processEvents()
 def test_queued_scan_action_cannot_switch_to_another_phone(self):
  self.bridge.update(busy=True,scanning=True,devices=[{'id':'phone'}])
  self.bridge.revealDeveloperMode()
  self.bridge.handle({'event':'devices','devices':[{'id':'other','trusted':True}]});APP.processEvents()
  self.assertFalse(any(item['command']=='reveal_developer_mode' for item in self.sent))
  self.assertTrue(self.bridge.data['error'])
 def test_untrusted_app_is_not_relaunched_after_poll_reconnect_or_desktop_restart(self):
  import json
  self.bridge.pendingSetup={'device':'phone','path':'fixture','mode':'account','email':'fixture@example.com','phase':'launch'}
  self.bridge.update(busy=False,devices=[{'id':'phone'}])
  self.bridge.launchDirectSide()
  self.assertTrue(json.loads(self.bridge.setupRecord.read_text())['launch_attempted'])
  restored=DesktopBridge(start=False,preferences=self.bridge.preferences);sent=[];restored.send=sent.append
  try:
   self.assertEqual(restored.data['launchState'],'blocked')
   restored.update(busy=False,loggedIn=True,email='fixture@example.com',devices=[{'id':'phone'}],developerMode='enabled')
   restored.resumeSetup();self.assertEqual(sent,[])
   restored.handle({'event':'devices','devices':[]})
   restored.handle({'event':'devices','devices':[{'id':'phone','trusted':True}]})
   restored.handle({'event':'device_components','device_id':'phone','developer_mode':True,'directside':True})
   self.assertFalse(any(item['command']=='launch_directside' for item in sent))
   restored.update(busy=False);restored.launchDirectSide()
   self.assertEqual(sent[-1],{'command':'launch_directside','device_id':'phone'})
  finally:restored.timer.stop()
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

 def test_settings_only_offer_the_available_update_action(self):
  from PySide6.QtTest import QTest
  self.bridge.update(busy=False,updateState='available',windowsUpdate=True,releaseVersion='v0.2.0',releaseIPA=True,bundledIPAReady=False)
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')))
  root=engine.rootObjects()[0];root.setWidth(960);root.setHeight(680)
  root.setProperty('page','settings');QTest.qWait(50)
  self.assertEqual(root.findChild(QObject,'installDirectSideButton').property('text'),'Install DirectSide')
  self.assertEqual(root.findChild(QObject,'ipaVersionBadge').property('text'),'v0.2.0')
  check=root.findChild(QObject,'settingsUpdateCheck');install=root.findChild(QObject,'settingsUpdateInstall')
  self.assertTrue(install.property('visible'));self.assertFalse(check.property('visible'))
  self.assertFalse(root.findChild(QObject,'windowsUpdateButton').property('visible'))
  self.bridge.update(updateBusy=True);APP.processEvents()
  self.assertFalse(install.property('visible'));self.assertFalse(check.property('visible'))
  self.bridge.update(updateBusy=False,windowsUpdate=False,updateState='current');APP.processEvents()
  self.assertFalse(install.property('visible'));self.assertTrue(check.property('visible'))
  root.close();engine.deleteLater();APP.processEvents()

 def test_primary_install_uses_current_adjacent_ipa_without_a_release(self):
  import plistlib,zipfile
  from unittest.mock import patch
  folder=Path(self.folder.name);ipa=folder/'DirectSide.ipa'
  with zipfile.ZipFile(ipa,'w') as archive:archive.writestr('Payload/DirectSide.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'com.directside.app','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'14'}))
  with patch('desktop.HOME',folder),patch('desktop.ROOT',folder):
   self.bridge.update(busy=False,loggedIn=True,devices=[{'id':'phone'}],releaseIPA=False,releaseVersion='',customIPA='other.ipa')
   self.bridge.installDirectSide()
  self.assertTrue(self.bridge.data['bundledIPAReady'])
  self.assertEqual(self.bridge.data['bundledIPAVersion'],'0.1.0 (14)')
  self.assertEqual(self.sent[-1]['command'],'install');self.assertEqual(self.sent[-1]['path'],str(ipa))
  self.assertEqual(self.sent[-1]['bundle_id'],'com.directside.app')
  self.assertEqual(self.bridge.data['customIPA'],'other.ipa')

 def test_adjacent_ipa_rejects_other_apps_corruption_and_older_versions(self):
  import plistlib,zipfile
  from unittest.mock import patch
  folder=Path(self.folder.name);ipa=folder/'DirectSide.ipa'
  with patch('desktop.HOME',folder),patch('desktop.ROOT',folder):
   for identifier,local_version,raw in [('other.app','0.1.0',False),('com.directside.app','0.1.0',True),('com.directside.app','0.0.1',False)]:
    if raw:ipa.write_bytes(b'not a zip')
    else:
     with zipfile.ZipFile(ipa,'w') as archive:archive.writestr('Payload/App.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':identifier,'CFBundleShortVersionString':local_version,'CFBundleVersion':'14'}))
    self.bridge.data['releaseVersion']='v0.1.0';self.bridge.refreshBundledIPA()
    self.assertFalse(self.bridge.data['bundledIPAReady'])

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
  main_button=root.findChild(QObject,'installDirectSideButton');custom_button=root.findChild(QObject,'installCustomIPAButton')
  for language in ('en','de'):
   for vpn in ('missing','installed'):
    self.bridge.update(language=language,vpnState=vpn)
    for _ in range(4):APP.processEvents()
    self.assertTrue(main_button.property('visible'));self.assertFalse(row.property('visible'))
    self.assertFalse(custom_button.property('visible'))
    top=card.mapToScene(QPointF(0,0));position=main_button.mapToScene(QPointF(0,0))
    self.assertLessEqual(position.y()+main_button.height(),top.y()+card.height()-20)
    self.assertIsNone(root.findChild(QObject,'vpnInstallPrompt'))
    self.assertTrue(root.findChild(QObject,'installDirectSideButton').property('enabled'))
  add_button=root.findChild(QObject,'addAppButton')
  self.assertTrue(add_button.property('visible'));self.assertTrue(add_button.property('enabled'))
  QMetaObject.invokeMethod(add_button,'clicked')
  from PySide6.QtTest import QTest
  QTest.qWait(50)
  self.assertFalse(main_button.property('visible'));self.assertTrue(row.property('visible'))
  self.assertTrue(custom_button.property('visible'));self.assertFalse(custom_button.property('enabled'))
  self.bridge.update(customIPA='example.ipa',customIPAName='Example app.ipa')
  QTest.qWait(50)
  self.assertTrue(custom_button.property('enabled'))
  custom_card=root.findChild(QObject,'customIPACard')
  top=custom_card.mapToScene(QPointF(0,0));position=row.mapToScene(QPointF(0,0))
  self.assertLessEqual(position.y()+row.height(),top.y()+custom_card.height()-20)
  self.assertLessEqual(position.x()+row.width(),top.x()+custom_card.width()-20)
  root.setProperty('page','settings')
  settings_card=root.findChild(QObject,'settingsCard');change=root.findChild(QObject,'settingsSigningChange')
  for language in ('en','de'):
   self.bridge.update(language=language);QTest.qWait(50)
   self.assertTrue(change.property('visible'))
   top=settings_card.mapToScene(QPointF(0,0));position=change.mapToScene(QPointF(0,0))
   self.assertLessEqual(position.y()+change.height(),top.y()+settings_card.height()-20)
   self.assertLessEqual(position.x()+change.width(),top.x()+settings_card.width()-20)
  root.close();engine.deleteLater();APP.processEvents()

 def test_app_removal_needs_confirmation_and_remains_device_scoped(self):
  self.bridge.update(busy=False,devices=[{'id':'phone'},{'id':'tablet'}],installedApps=[{'id':'third.party.app','name':'Other installer app','developer':True}])
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
  self.assertEqual(self.sent,[{'command':'repair_directside','signing_mode':'account','device_id':'tablet','path':str(ipa)}])
  self.assertTrue(self.bridge.data['settingUp']);self.assertEqual(self.bridge.data['challenge'],'')
  self.assertFalse(self.bridge.repairDirectSide());self.assertEqual(len(self.sent),1)

 def test_usb_pairing_progress_is_visible_without_a_code_challenge_and_clears_on_error(self):
  self.bridge.update(busy=True,vpnState='missing')
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.handle({'event':'status','phase':'device_setup','message':'USB-Kopplung automatisch bestätigen …'});APP.processEvents()
  self.assertTrue(root.findChild(QObject,'deviceSetupProgress').property('visible'))
  self.assertIsNone(root.findChild(QObject,'vpnInstallPrompt'))
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
  self.bridge.handle({'event':'device_components','device_id':'phone','developer_mode':False,'directside':True});APP.processEvents()
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
 def test_regular_app_store_apps_cannot_be_removed(self):
  self.bridge.update(busy=False,devices=[{'id':'phone'}],installedApps=[{'id':'store.app','name':'Store app','developer':False}])
  self.bridge.requestAppRemoval('store.app');self.bridge.confirmRemoval()
  self.assertEqual(self.sent,[])
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.assertEqual(root.property('filteredApps').toVariant(),[])
  root.close();engine.deleteLater();APP.processEvents()

 def test_imported_identity_signs_without_apple_login_and_mode_survives_restart(self):
  import plistlib
  from zipfile import ZipFile
  ipa=Path(self.folder.name)/'app.ipa'
  with ZipFile(ipa,'w') as archive:archive.writestr('Payload/App.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'example.app'}))
  self.bridge.update(busy=False,devices=[{'id':'phone'}],loggedIn=False,ipa=str(ipa),importedIdentity={'name':'Fixture profile'})
  self.bridge.setSigningMode('imported');self.bridge.install()
  self.assertEqual(self.sent[-1]['command'],'install')
  self.assertEqual(self.sent[-1]['signing_mode'],'imported')
  self.assertEqual(self.bridge.preferences.load()['signing_mode'],'imported')
  self.assertNotIn('password',self.bridge.preferences.path.read_text())
  self.bridge.update(busy=False);self.bridge.handle({'event':'imported_identity','identity':None})
  self.assertFalse(self.bridge.data['canSign'])

 def test_import_certificate_request_has_password_only_in_protocol_not_state(self):
  self.bridge.update(busy=False,identityP12='fixture.p12',identityProfiles=['main.mobileprovision','extension.mobileprovision'])
  self.bridge.importIdentity('fixture-only-password')
  self.assertEqual(self.sent[-1],{'command':'import_identity','p12_path':'fixture.p12','profile_paths':['main.mobileprovision','extension.mobileprovision'],'password':'fixture-only-password'})
  self.assertNotIn('fixture-only-password',str(self.bridge.data))
  self.assertNotIn('fixture-only-password',self.bridge.preferences.path.read_text())

 def test_certificate_file_selection_is_not_lost_during_a_device_check(self):
  from unittest.mock import patch
  for method,dialog,result,key,expected in [
   ('chooseIdentityCertificate','getOpenFileName',('fixture.p12',''),'identityP12','fixture.p12'),
   ('chooseIdentityProfiles','getOpenFileNames',(['fixture.mobileprovision'],''),'identityProfiles',['fixture.mobileprovision'])]:
   self.bridge.update(busy=True,scanning=True)
   with patch('desktop.QFileDialog.'+dialog,return_value=result) as choose:
    getattr(self.bridge,method)();choose.assert_not_called()
    self.bridge.update(busy=False,scanning=False)
    self.bridge.startPendingUserAction();APP.processEvents()
    choose.assert_called_once()
   self.assertEqual(self.bridge.data[key],expected)

 def test_imported_signing_form_stays_inside_compact_window(self):
  from PySide6.QtCore import QPointF
  from PySide6.QtTest import QTest
  self.bridge.update(busy=False,loggedIn=False)
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  root.setProperty('page','identity');root.setWidth(960);root.setHeight(680);APP.processEvents()
  card=root.findChild(QObject,'importedSigningCard');button=root.findChild(QObject,'importIdentityButton')
  self.assertTrue(card.property('visible'))
  self.assertFalse(root.findChild(QObject,'certificateImportFields').property('visible'))
  self.bridge.update(signingMode='imported');QTest.qWait(50)
  self.assertTrue(root.findChild(QObject,'certificateImportFields').property('visible'))
  point=button.mapToScene(QPointF(0,0));top=card.mapToScene(QPointF(0,0))
  self.assertGreaterEqual(point.y(),top.y())
  self.assertLessEqual(point.y()+button.height(),top.y()+card.height())
  self.assertFalse(button.property('enabled'))
  root.close();engine.deleteLater();APP.processEvents()

 def test_help_shows_only_the_current_setup_step_and_calls_logs_a_log(self):
  self.bridge.update(busy=False,language='en',usbState='missing',devices=[],releaseIPA=True,bundledIPAReady=True)
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  root.setProperty('page','help');APP.processEvents()
  self.assertTrue(root.findChild(QObject,'helpAppleSetup').property('visible'))
  self.assertFalse(root.findChild(QObject,'helpInstall').property('visible'))
  self.bridge.update(usbState='ready');APP.processEvents()
  self.assertEqual(root.property('helpStep'),'connect')
  self.assertTrue(root.findChild(QObject,'helpConnectCheck').property('visible'))
  self.bridge.update(devices=[{'id':'phone'}]);APP.processEvents()
  self.assertEqual(root.property('helpStep'),'account')
  self.assertFalse(root.findChild(QObject,'helpConnectCheck').property('visible'))
  self.bridge.update(loggedIn=True);APP.processEvents()
  self.assertTrue(root.findChild(QObject,'helpInstall').property('visible'))
  self.bridge.update(directsidePresent=True,developerMode='unknown');APP.processEvents()
  self.assertEqual(root.findChild(QObject,'helpNextTitle').property('text'),'Check iPhone status')
  self.assertFalse(root.findChild(QObject,'helpDeveloper').property('visible'))
  self.bridge.update(developerMode='disabled');APP.processEvents()
  self.assertTrue(root.findChild(QObject,'helpDeveloper').property('visible'))
  self.bridge.update(developerMode='enabled');APP.processEvents()
  self.assertEqual(root.property('helpStep'),'iphone')
  self.assertFalse(root.findChild(QObject,'repairDirectSideButton').property('visible'))
  root.setProperty('helpTrouble',True);APP.processEvents()
  self.assertTrue(root.findChild(QObject,'repairDirectSideButton').property('visible'))
  self.bridge.update(busy=True);APP.processEvents()
  self.assertFalse(root.findChild(QObject,'repairDirectSideButton').property('visible'))
  log=root.findChild(QObject,'helpLogButton');self.assertFalse(log.property('visible'))
  self.bridge.update(busy=False,logs=['fixture event']);APP.processEvents()
  self.assertTrue(log.property('visible'));self.assertEqual(log.property('text'),'Log')
  QMetaObject.invokeMethod(log,'clicked');APP.processEvents()
  self.assertEqual(root.property('page'),'activity')
  root.close();engine.deleteLater();APP.processEvents()

 def test_app_id_details_do_not_block_or_finish_an_installation(self):
  self.bridge.update(loggedIn=True,busy=True)
  self.assertTrue(self.bridge.loadAppIds())
  self.assertEqual(self.sent,[{'command':'app_ids'}])
  self.assertTrue(self.bridge.data['busy'])
  self.assertTrue(self.bridge.loadAppIds())
  self.assertEqual(len(self.sent),1)
  self.bridge.handle({'event':'app_ids','limit':10,'available':1,'ids':[
   {'name':'Widget','identifier':'example.main.TEST.Widget','parent_name':'Main','expires_at':'2026-10-30T12:00:00Z'},
   {'name':'Main','identifier':'example.main.TEST','parent_name':None,'expires_at':'2026-10-30T12:00:00Z'}]})
  self.assertTrue(self.bridge.data['busy'])
  self.assertFalse(self.bridge.data['appIdsLoading'])
  self.assertEqual(self.bridge.data['appIds'][1]['parent_name'],'Main')
  self.assertEqual(self.bridge.data['appIdsAvailable'],1)
  self.bridge.handle({'event':'error','command':'app_ids','message':'Temporary failure'})
  self.assertTrue(self.bridge.data['busy'])
  self.assertTrue(self.bridge.data['loggedIn'])
  self.assertTrue(self.bridge.data['appIdsError'])
  self.assertFalse(self.bridge.data['error'])
  self.bridge.handle({'event':'logged_out'})
  self.assertEqual(self.bridge.data['appIds'],[])

 def test_fresh_setup_waits_for_developer_mode_and_resumes_after_reconnect(self):
  ipa=Path(self.folder.name)/'DirectSide.ipa';ipa.write_bytes(b'pending original fixture')
  self.bridge.initializing=False
  self.bridge.update(busy=False,loggedIn=True,email='person@example.com',devices=[{'id':'phone'}])
  self.bridge.handle({'event':'installed','device_id':'phone','path':str(ipa),'developer_mode_required':True,'bootstrap_ready':False})
  self.assertTrue(self.bridge.data['setupPending']);self.assertFalse(self.bridge.data['success'])
  self.assertTrue(self.bridge.setupRecord.is_file())
  self.sent.clear()
  self.bridge.handle({'event':'device_components','device_id':'phone','developer_mode':False,'directside':True})
  self.assertFalse(any(e['command']=='repair_directside' for e in self.sent))
  self.bridge.handle({'event':'devices','devices':[]})
  self.assertTrue(self.bridge.data['setupPending'])
  self.bridge.handle({'event':'devices','devices':[{'id':'phone','name':'iPhone'}]})
  self.sent.clear()
  self.bridge.handle({'event':'device_components','device_id':'phone','developer_mode':True,'directside':True})
  self.assertEqual(self.sent,[{'command':'repair_directside','signing_mode':'account','device_id':'phone','path':str(ipa)}])
  self.assertTrue(self.bridge.data['settingUp'])
  self.bridge.handle({'event':'directside_repaired','device_id':'phone'})
  self.assertFalse(self.bridge.data['setupReady']);self.assertTrue(self.bridge.setupRecord.exists())
  self.assertEqual(self.sent[-1],{'command':'launch_directside','device_id':'phone'})
  self.bridge.handle({'event':'directside_launch_result','device_id':'phone','ok':False})
  self.assertFalse(self.bridge.data['setupReady']);self.assertFalse(self.bridge.data['success'])
  self.assertEqual(self.sent[-1],{'command':'open_trust_settings','device_id':'phone'})
  self.bridge.handle({'event':'trust_settings_opened','device_id':'phone','ok':False})
  self.assertEqual(self.bridge.data['settingsNavigation'],'manual')
  self.bridge.launchDirectSide()
  self.bridge.handle({'event':'directside_launch_result','device_id':'phone','ok':True})
  self.assertFalse(self.bridge.data['setupPending']);self.assertTrue(self.bridge.data['setupReady'])
  self.assertFalse(self.bridge.setupRecord.exists())

 def test_failed_settings_navigation_shows_manual_fallback_at_same_step(self):
  self.bridge.pendingSetup={'device':'phone','path':'fixture','mode':'account','email':'fixture@example.com','phase':'launch'}
  self.bridge.update(busy=False,devices=[{'id':'phone'}],launchState='blocked')
  engine=QQmlApplicationEngine();engine.rootContext().setContextProperty('backend',self.bridge)
  engine.load(QUrl.fromLocalFile(str(ROOT/'ui'/'Main.qml')));root=engine.rootObjects()[0]
  self.bridge.handle({'event':'trust_settings_opened','device_id':'phone','ok':False});APP.processEvents()
  fallback=root.findChild(QObject,'manualTrustFallback')
  self.assertTrue(fallback.property('visible'));self.assertEqual(root.property('page'),'launch')
  self.assertFalse(self.bridge.data['setupReady'])
  self.assertEqual(fallback.property('text'),'Please open this on your iPhone:')
  self.bridge.setLanguage('de');APP.processEvents()
  self.assertEqual(fallback.property('text'),'Bitte am iPhone selbst öffnen:')
  root.close();engine.deleteLater();APP.processEvents()

 def test_pending_setup_survives_restart_and_cannot_target_another_phone(self):
  ipa=Path(self.folder.name)/'DirectSide.ipa';ipa.write_bytes(b'pending fixture')
  self.bridge.setupRecord.write_text(__import__('json').dumps({'device':'original','path':str(ipa),'mode':'account','email':'person@example.com'}))
  restored=DesktopBridge(start=False,preferences=self.bridge.preferences);sent=[];restored.send=sent.append
  try:
   restored.update(busy=False,loggedIn=True,email='person@example.com',devices=[{'id':'different'}],developerMode='enabled')
   restored.resumeSetup();self.assertEqual(sent,[])
   restored.update(devices=[{'id':'original'}],developerMode='unknown');restored.resumeSetup();self.assertEqual(sent,[])
   restored.update(developerMode='enabled');restored.resumeSetup()
   self.assertEqual(sent[0]['device_id'],'original')
  finally:restored.timer.stop()

 def test_usb_trust_is_guided_once_and_existing_trust_is_reused(self):
  self.bridge.initializing=False
  self.bridge.handle({'event':'devices','devices':[{'id':'fresh','name':'iPhone','trusted':False}]})
  self.assertEqual(self.sent,[{'command':'trust_device','device_id':'fresh'}])
  self.assertTrue(self.bridge.data['usbTrustPending'])
  self.bridge.handle({'event':'error','command':'trust_device','message':'UserDeniedPairing'})
  self.sent.clear()
  self.bridge.handle({'event':'devices','devices':[{'id':'fresh','name':'iPhone','trusted':False}]})
  self.assertEqual(self.sent,[])
  self.bridge.trustDevice();self.assertEqual(self.sent,[{'command':'trust_device','device_id':'fresh'}])
  self.bridge.handle({'event':'device_trusted','device_id':'fresh'})
  self.assertFalse(self.bridge.data['usbTrustPending'])
  self.sent.clear()
  self.bridge.handle({'event':'devices','devices':[{'id':'fresh','name':'iPhone','trusted':True}]})
  self.assertFalse(any(e['command']=='trust_device' for e in self.sent))

if __name__=='__main__':unittest.main()
