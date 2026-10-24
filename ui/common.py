"""DirectSide's native Windows bootstrap application. Credentials travel over stdin only."""
from __future__ import annotations
import json
import os
import plistlib
import re
import sys
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parents[1]))
HOME = Path(sys.executable).parent if getattr(sys, 'frozen', False) else ROOT

class Preferences:
    """Non-secret preferences only. Authentication remains in the OS keyring."""
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(os.environ.get('LOCALAPPDATA', Path.home()/'AppData'/'Local'))/'DirectSide'/'preferences.json'

    def load(self):
        try:
            data = json.loads(self.path.read_text(encoding='utf-8'))
            result={key: data[key] for key in ('email',) if isinstance(data.get(key), str)}
            result['language']=data.get('language') if data.get('language') in ('en','de') else 'en'
            return result
        except (OSError, ValueError, AttributeError):
            return {}

    def save(self, email, language='en'):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_suffix('.tmp')
        temp.write_text(json.dumps({'email':email.strip(),'language':language if language in ('en','de') else 'en'}, ensure_ascii=False), encoding='utf-8')
        temp.replace(self.path)

def valid_code(value):
    return len(value) == 6 and value.isascii() and value.isdigit()

def ipa_identity(path: Path) -> str:
    with ZipFile(path) as archive:
        files = [n for n in archive.namelist() if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        if len(files) != 1:
            raise ValueError('Die IPA enthält keine eindeutige Haupt-App.')
        info = archive.getinfo(files[0])
        if info.file_size > 2_000_000:
            raise ValueError('Die App-Metadaten sind ungewöhnlich groß.')
        return str(plistlib.loads(archive.read(files[0])).get('CFBundleIdentifier', ''))

def clean_error(value: str) -> str:
    value = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[Apple-ID]', value)
    return value[:4000]
