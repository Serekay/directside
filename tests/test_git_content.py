"""Exercise the commit guard against real staged Git changes."""
import contextlib
import importlib.util
import io
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('git_content_guard',ROOT/'scripts/check-git-content.py')
guard=importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class GitContentGuardTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory(prefix='directside-guard-test-')
        self.root=Path(self.folder.name)
        for args in [['init','-q'],['config','user.name','Test'],['config','user.email','1+test@users.noreply.github.com']]:
            subprocess.run(['git',*args],cwd=self.root,check=True,capture_output=True)
    def tearDown(self):self.folder.cleanup()
    def stage(self,name,content):
        (self.root/name).write_text(content,encoding='utf-8')
        subprocess.run(['git','add','--',name],cwd=self.root,check=True,capture_output=True)
    def check(self):
        binary=ROOT/'.tools/gitleaks/gitleaks.exe'
        binary=str(binary) if binary.is_file() else shutil.which('gitleaks')
        with patch.object(guard,'ROOT',self.root),patch.object(guard.shutil,'which',return_value=binary),contextlib.redirect_stdout(io.StringIO()),contextlib.redirect_stderr(io.StringIO()):
            return guard.main()
    def test_environment_file_is_rejected_before_secret_scan(self):
        self.stage('.env','LOCAL_SETTING=value\n')
        self.assertEqual(self.check(),1)
    def test_safe_change_is_accepted(self):
        if not (ROOT/'.tools/gitleaks/gitleaks.exe').is_file() and not shutil.which('gitleaks'):self.skipTest('Gitleaks not installed')
        self.stage('README.md','Project documentation\n')
        self.assertEqual(self.check(),0)
    def test_token_in_an_ordinary_source_file_is_rejected(self):
        if not (ROOT/'.tools/gitleaks/gitleaks.exe').is_file() and not shutil.which('gitleaks'):self.skipTest('Gitleaks not installed')
        import secrets
        self.stage('example.py','token = "'+('gh'+'p_'+secrets.token_hex(18))+'"\n')
        self.assertEqual(self.check(),1)
