"""Qt UI tests use dummy protocol events and never contact Apple."""
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
from PySide6.QtCore import QUrl,Qt
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
if __name__=='__main__':unittest.main()
