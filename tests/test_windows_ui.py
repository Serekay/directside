"""UI state tests with fake protocol events; no Apple requests or credentials."""
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tkinter import ttk

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
from app import DirectSide, Preferences

class WindowsUIStateTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.preferences=patch('app.Preferences', return_value=Preferences(Path(self.folder.name)/'preferences.json'))
        self.preferences.start()
        self.window=DirectSide()
        self.window.withdraw()
        self.sent=[]
        self.window.send=self.sent.append

    def tearDown(self):
        self.window.progress.stop()
        for callback in self.window.tk.call('after','info'):
            self.window.tk.call('after','cancel',callback)
        self.window.destroy()
        self.preferences.stop()
        self.folder.cleanup()

    def test_code_stays_inline_and_invalid_input_is_not_sent(self):
        self.window.two_factor({'numbers':[]})
        self.assertEqual(self.window.challenge_kind,'two_factor')
        self.assertFalse(any(child.winfo_class()=='Toplevel' for child in self.window.winfo_children()))
        entry=next(child for child in self.window.challenge.winfo_children() if isinstance(child,ttk.Entry))
        entry.insert(0,'123')
        self.window.challenge_buttons[0].invoke()
        self.assertEqual(self.sent,[])
        self.assertTrue(self.window.challenge_hint.get())
        entry.delete(0,'end');entry.insert(0,'012345')
        self.window.challenge_buttons[0].invoke()
        self.assertEqual(self.sent,[{'action':'code','code':'012345'}])
        self.assertIsNone(self.window.challenge_kind)

    def test_team_cancel_and_error_return_to_main_window(self):
        self.window.select_team([{'id':'TEST','name':'Test team'}])
        self.window.challenge_buttons[-1].invoke()
        self.assertEqual(self.sent,[{'team_id':''}])
        self.window.show_error('Test failure')
        self.assertEqual(self.window.status.get(),'Test failure')
        self.assertFalse(self.window.busy)

    def test_restoring_session_does_not_queue_commands_ahead_of_challenge(self):
        self.window.handle_event({'event':'ready'})
        self.assertEqual(self.sent,[{'command':'restore'}])
        self.window.handle_event({'event':'logged_out'})
        self.assertEqual(self.sent[-1],{'command':'devices'})
        self.assertTrue(self.window.busy)
        self.window.handle_event({'event':'devices','devices':[]})
        self.assertEqual(str(self.window.install_button['state']),'disabled')

    def test_installation_success_has_inline_next_steps(self):
        self.window.handle_event({'event':'installed'})
        self.assertEqual(self.window.success.winfo_manager(),'pack')
        self.assertEqual(self.window.progress['value'],100)

    def test_restored_account_prefills_identity_and_collapses_password_fields(self):
        self.window.initializing=False
        self.window.handle_event({'event':'logged_in','team':'Test team','email':'person@example.com'})
        self.assertEqual(self.window.email.get(),'person@example.com')
        self.assertEqual(self.window.preferences.load()['email'],'person@example.com')
        self.assertEqual(self.window.password_entry.winfo_manager(),'')
        self.window.handle_event({'event':'logged_out'})
        self.assertEqual(self.window.password_entry.winfo_manager(),'grid')

if __name__=='__main__':unittest.main()
