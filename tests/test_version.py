"""Prevent Windows, iPhone and native-engine version drift."""
import re
import sys
import tomllib
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'ui'))
from updates import VERSION, BUILD

class VersionTests(unittest.TestCase):
    def test_all_platforms_share_the_version_and_build(self):
        project=(ROOT/'ios/project.yml').read_text(encoding='utf-8')
        self.assertEqual(re.search(r"MARKETING_VERSION: '([^']+)'",project)[1],VERSION)
        self.assertEqual(int(re.search(r"CURRENT_PROJECT_VERSION: '(\d+)'",project)[1]),BUILD)
        manifest=tomllib.loads((ROOT/'Cargo.toml').read_text())
        lock=tomllib.loads((ROOT/'Cargo.lock').read_text())
        self.assertEqual(manifest['package']['version'],VERSION)
        self.assertEqual(next(p['version'] for p in lock['package'] if p['name']=='directside-engine'),VERSION)
        self.assertGreater(BUILD,0)
