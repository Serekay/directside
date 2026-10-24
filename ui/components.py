"""Windows prerequisites and vendor-verified setup, invoked by an explicit UI action."""
import ctypes
import hashlib
import os
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import build_opener, HTTPRedirectHandler

# Pinned Microsoft winget manifest; binary is downloaded directly from Apple.
# microsoft/winget-pkgs@957fd06197fb2512713d3588fdabc7584a42c4a2
# manifests/a/Apple/iTunes/12.13.10.3/Apple.iTunes.installer.yaml (x64)
APPLE_SETUP_URL='https://secure-appldnld.apple.com/itunes12/047-76416-20260302-fefe4356-211d-4da1-8bc4-058eb36ea803/iTunes64Setup.exe'
APPLE_SETUP_SHA256='CEA2A74CAE3F061EADC11358EEAAE9B40CFDEA9EC1EE037B47DA54A64219E182'

# Official standalone release; no embedded SideStore. Digest from GitHub release asset.
LIVECONTAINER_VERSION='3.8.0'
LIVECONTAINER_URL='https://github.com/LiveContainer/LiveContainer/releases/download/3.8.0/LiveContainer.ipa'
LIVECONTAINER_SHA256='b6fea95e30083382e29ffef88fa1aaa40b5069e1112e5307d490dab04648bba6'

def download_livecontainer(event):
    folder=Path(os.environ.get('LOCALAPPDATA',Path.home()))/'DirectSide'/'downloads';folder.mkdir(parents=True,exist_ok=True)
    path=folder/f'LiveContainer-{LIVECONTAINER_VERSION}.ipa'
    def valid(file):
        return file.is_file() and hashlib.sha256(file.read_bytes()).hexdigest()==LIVECONTAINER_SHA256
    if not valid(path):
        event({'type':'status','message':'LiveContainer herunterladen …'})
        partial=path.with_suffix('.download')
        # GitHub redirects release assets to its dedicated asset CDN.
        class ReleaseRedirects(HTTPRedirectHandler):
            def redirect_request(self,request,fp,code,message,headers,new_url):
                parsed=urlsplit(new_url)
                if parsed.scheme!='https' or parsed.hostname not in ('github.com','release-assets.githubusercontent.com','objects.githubusercontent.com') or parsed.username or parsed.password:raise RuntimeError('Unerwarteter LiveContainer-Downloadserver.')
                return super().redirect_request(request,fp,code,message,headers,new_url)
        with build_opener(ReleaseRedirects()).open(LIVECONTAINER_URL,timeout=45) as response,partial.open('wb') as f:
            total=int(response.headers.get('Content-Length','0'));done=0
            while block:=response.read(1024*1024):
                done+=len(block)
                if done>100_000_000:raise RuntimeError('LiveContainer-Download ist unerwartet groß.')
                f.write(block);event({'type':'progress','value':min(90,int(done/total*90)) if total else 0})
        if not valid(partial):partial.unlink(missing_ok=True);raise RuntimeError('LiveContainer-Prüfsumme stimmt nicht.')
        partial.replace(path)
    event({'type':'livecontainer_downloaded','path':str(path)})

def apple_url(url):
    p=urlsplit(url);host=p.hostname or ''
    return p.scheme=='https' and (host=='apple.com' or host.endswith('.apple.com')) and not p.username and not p.password

class AppleRedirects(HTTPRedirectHandler):
    def redirect_request(self,request,fp,code,message,headers,new_url):
        if not apple_url(new_url):raise RuntimeError('Download wurde auf einen fremden Server umgeleitet.')
        return super().redirect_request(request,fp,code,message,headers,new_url)

def verified_installer(path):
    try:
        h=hashlib.sha256()
        with Path(path).open('rb') as f:
            for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
        return h.hexdigest().upper()==APPLE_SETUP_SHA256
    except OSError:return False

def usb_status():
    if os.name!='nt':return 'unsupported'
    from ctypes import wintypes as w
    api=ctypes.WinDLL('advapi32',use_last_error=True)
    api.OpenSCManagerW.argtypes=[w.LPCWSTR,w.LPCWSTR,w.DWORD];api.OpenSCManagerW.restype=w.HANDLE
    api.OpenServiceW.argtypes=[w.HANDLE,w.LPCWSTR,w.DWORD];api.OpenServiceW.restype=w.HANDLE
    api.CloseServiceHandle.argtypes=[w.HANDLE]
    class Status(ctypes.Structure):_fields_=[(n,w.DWORD) for n in ['type','state','accepted','exit','specific','checkpoint','wait']]
    api.QueryServiceStatus.argtypes=[w.HANDLE,ctypes.POINTER(Status)]
    manager=api.OpenSCManagerW(None,None,1)
    if not manager:return 'unknown'
    service=api.OpenServiceW(manager,'Apple Mobile Device Service',4)
    try:
        if not service:return 'missing' if ctypes.get_last_error()==1060 else 'unknown'
        status=Status()
        if not api.QueryServiceStatus(service,ctypes.byref(status)):return 'unknown'
        return 'ready' if status.state==4 else 'stopped'
    finally:
        if service:api.CloseServiceHandle(service)
        api.CloseServiceHandle(manager)

def elevated(file,arguments):
    """Use Windows' normal elevation prompt; never bypass UAC or security checks."""
    from ctypes import wintypes as w
    class Execute(ctypes.Structure):
        _fields_=[('size',w.DWORD),('mask',w.ULONG),('window',w.HWND),('verb',w.LPCWSTR),('file',w.LPCWSTR),('args',w.LPCWSTR),('directory',w.LPCWSTR),('show',ctypes.c_int),('instance',w.HINSTANCE),('idList',ctypes.c_void_p),('className',w.LPCWSTR),('key',w.HKEY),('hotKey',w.DWORD),('icon',w.HANDLE),('process',w.HANDLE)]
    info=Execute();info.size=ctypes.sizeof(info);info.mask=0x40;info.verb='runas';info.file=str(file);info.args=arguments;info.show=1
    shell=ctypes.WinDLL('shell32',use_last_error=True);shell.ShellExecuteExW.argtypes=[ctypes.POINTER(Execute)]
    if not shell.ShellExecuteExW(ctypes.byref(info)):
        if ctypes.get_last_error()==1223:raise RuntimeError('Einrichtung abgebrochen.')
        raise ctypes.WinError(ctypes.get_last_error())
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.WaitForSingleObject.argtypes=[w.HANDLE,w.DWORD];kernel.GetExitCodeProcess.argtypes=[w.HANDLE,ctypes.POINTER(w.DWORD)];kernel.CloseHandle.argtypes=[w.HANDLE]
    try:
        if kernel.WaitForSingleObject(info.process,15*60*1000)!=0:raise RuntimeError('Einrichtung läuft noch. Komponenten anschließend erneut prüfen.')
        code=w.DWORD()
        if not kernel.GetExitCodeProcess(info.process,ctypes.byref(code)):raise ctypes.WinError(ctypes.get_last_error())
        return code.value
    finally:kernel.CloseHandle(info.process)

def setup_apple(event):
    """Runs in a worker thread. Already healthy installations are left alone."""
    state=usb_status()
    if state=='ready':event({'type':'done','message':'Apple USB ist bereits bereit.'});return
    if state=='stopped':
        event({'type':'status','message':'Apple USB starten …'})
        result=elevated(Path(os.environ['SystemRoot'])/'System32'/'sc.exe','start "Apple Mobile Device Service"')
    else:
        folder=Path(os.environ.get('LOCALAPPDATA',Path.home()))/'DirectSide'/'setup';folder.mkdir(parents=True,exist_ok=True)
        path=folder/'iTunes64Setup.exe'
        if not verified_installer(path):
            event({'type':'status','message':'Apple USB / iTunes herunterladen …'})
            partial=path.with_suffix('.download')
            with build_opener(AppleRedirects()).open(APPLE_SETUP_URL,timeout=45) as response,partial.open('wb') as f:
                total=int(response.headers.get('Content-Length','0'));done=0
                while block:=response.read(1024*1024):
                    done+=len(block)
                    if done>600_000_000:raise RuntimeError('Installer überschreitet die erlaubte Größe.')
                    f.write(block);event({'type':'progress','value':min(85,int(done/total*85)) if total else 0})
            if not verified_installer(partial):
                partial.unlink(missing_ok=True);raise RuntimeError('Apple-Installer-Prüfsumme stimmt nicht. Installation gestoppt.')
            partial.replace(path)
        event({'type':'status','message':'Apple USB / iTunes einrichten …'})
        result=elevated(path,'/passive /norestart')
    if result not in (0,3010):raise RuntimeError(f'Apple-Einrichtung wurde nicht abgeschlossen (Code {result}).')
    state=usb_status()
    event({'type':'done','message':'Windows-Neustart erforderlich.' if result==3010 else 'Apple USB ist bereit.' if state=='ready' else 'Einrichtung beendet. Komponenten erneut prüfen.'})
