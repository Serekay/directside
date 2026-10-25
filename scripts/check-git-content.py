"""Reject local credentials and scan staged changes without printing secrets."""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def main():
    paths=subprocess.check_output(['git','diff','--cached','--name-only','--diff-filter=ACMR','-z'],cwd=ROOT).decode().split('\0')
    suffixes={'.p12','.pfx','.p8','.pem','.key','.mobileprovision','.mobiledevicepairing','.dpapi','.ipa','.exe','.dll','.log','.sqlite','.sqlite3'}
    for name in filter(None,paths):
        path=Path(name)
        if path.suffix.lower() in suffixes or any(p in {'.tools','build','dist','target','.claude','.codex'} for p in path.parts) or path.name=='.env' or (path.name.startswith('.env.') and path.name!='.env.example'):
            print('Commit blocked: a local credential, binary or diagnostic file is staged.',file=sys.stderr)
            return 1
    email=subprocess.check_output(['git','var','GIT_AUTHOR_IDENT'],cwd=ROOT,text=True).split('<',1)[1].split('>',1)[0]
    if not email.endswith('@users.noreply.github.com'):
        print('Commit blocked: configure a GitHub noreply author address.',file=sys.stderr)
        return 1
    local=ROOT/'.tools/gitleaks/gitleaks.exe'
    executable=str(local) if local.is_file() else shutil.which('gitleaks')
    if not executable:
        print('Commit blocked: install Gitleaks to check staged changes.',file=sys.stderr)
        return 1
    result=subprocess.run([executable,'git','--pre-commit','--staged','--redact=100','--ignore-gitleaks-allow','--no-banner',str(ROOT)],cwd=ROOT,capture_output=True)
    if result.returncode:
        print('Commit blocked: the secret scan found a problem or could not complete. Review staged changes locally.',file=sys.stderr)
        return 1
    print('Staged credential and secret checks passed.')
    return 0

if __name__=='__main__':sys.exit(main())
