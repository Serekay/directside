"""Small bundled desktop dictionary. English is the default; no online translation."""
import json
from pathlib import Path

ENGLISH=json.loads((Path(__file__).with_name('en.json')).read_text(encoding='utf-8'))
GERMAN={english:german for german,english in ENGLISH.items()}

def translate(value,language):
    mapping=GERMAN if language=='de' else ENGLISH
    if value in mapping:return mapping[value]
    for source,target in mapping.items():
        if source.endswith(': ') and value.startswith(source):return target+value[len(source):]
    return value
