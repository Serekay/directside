"""Private local helper: Apple CoreADI runs inside the packaged app, without a server.

Only Anisette data crosses its private pipes. Apple-ID credentials never enter it.
"""
import base64
import ctypes
import hashlib
import json
import os
import ssl
import struct
import sys
import threading
import urllib.parse
import urllib.request
from pathlib import Path
from ctypes import wintypes

ROOT=Path(getattr(sys,'_MEIPASS',Path(__file__).resolve().parents[1]))
RUNTIME=ROOT/'bin/apple/CoreADI.mac'
HASH='2eafc3c79c7f41a8afbfbeaaf23ee5dab5ad5bda55ec8e54dbc0ddf1d20ce630'
TRACE_SINK=None

def trace(stage):
    if TRACE_SINK:TRACE_SINK(stage)
    if os.environ.get('DIRECTSIDE_AUTH_DIAGNOSTICS')=='1' and sys.stderr is not None:print('Local runtime stage: '+stage,file=sys.stderr,flush=True)

class Blob(ctypes.Structure):
    _fields_=[('size',wintypes.DWORD),('data',ctypes.POINTER(ctypes.c_ubyte))]

def protect(data,decrypt=False):
    buffer=ctypes.create_string_buffer(data);source=Blob(len(data),ctypes.cast(buffer,ctypes.POINTER(ctypes.c_ubyte)));out=Blob()
    crypt=ctypes.WinDLL('crypt32',use_last_error=True)
    fn=crypt.CryptUnprotectData if decrypt else crypt.CryptProtectData
    fn.argtypes=[ctypes.POINTER(Blob),ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,wintypes.DWORD,ctypes.POINTER(Blob)]
    fn.restype=wintypes.BOOL
    if not fn(ctypes.byref(source),None,None,None,None,1,ctypes.byref(out)):raise OSError('Local identity protection failed')
    try:return ctypes.string_at(out.data,out.size)
    finally:
        kernel=ctypes.WinDLL('kernel32');kernel.LocalFree.argtypes=[ctypes.c_void_p];kernel.LocalFree(out.data)

def apple_url(url):
    p=urllib.parse.urlparse(url)
    if p.scheme!='https' or not p.hostname or not(p.hostname=='apple.com' or p.hostname.endswith('.apple.com')) or p.username or p.password:raise ValueError('Invalid Apple provisioning endpoint')
    return url

def export_identity(saved):
    """Normalize the protected local machine context for one trusted USB handoff."""
    identity=saved.get('identity',{})
    host=bytes.fromhex(identity['host_uuid'])
    if len(host)!=16:raise ValueError('Invalid local identity')
    store=bytearray()
    for name,value in sorted(saved.get('store',{}).items()):
        if name=='adi.pb':continue
        if not name or '/' in name or '\\' in name or len(name)>128:raise ValueError('Invalid local store')
        filename=name.encode('utf-8');blob=base64.b64decode(value,validate=True)
        store+=struct.pack('>H',len(filename))+filename+struct.pack('>I',len(blob))+blob
        if len(store)>65536:raise ValueError('Local store exceeds its limit')
    if not store:raise ValueError('Local identity is not provisioned')
    return {'host':base64.b64encode(host).decode(),'device':identity['device_id'],'user':identity['local_user_uuid'],'serial':identity['serial'],'store':base64.b64encode(store).decode()}

def run(request):
    trace('runtime verification')
    if hashlib.sha256(RUNTIME.read_bytes()).hexdigest()!=HASH:raise ValueError('Local Apple runtime checksum mismatch')
    os.environ['COREADI_PATH']=str(RUNTIME)
    os.environ.pop('COREADI_DISPATCH',None);os.environ.pop('ADI_FROZEN_TIME',None)
    sys.path.insert(0,str(ROOT/'vendor/mac-adi-python'))
    import cooldown
    from mac_anisette import MacAnisette,DS_ID,STORE_DIR
    from gsa import GSA,Device
    trace('provider imported')
    state=Path(os.environ['LOCALAPPDATA'])/'DirectSide/local-mac-auth';state.mkdir(parents=True,exist_ok=True)
    cooldown.MARKER=state/'apple-throttle';cooldown.guard()
    import msvcrt
    with (state/'identity.lock').open('a+b') as lock:
        lock.seek(0);lock.write(b'\0');lock.flush();lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_LOCK,1)
        protected=state/'identity.dpapi'
        saved=json.loads(protect(protected.read_bytes(),True)) if protected.exists() else {}
        if request.get('operation')=='export_identity':return export_identity(saved)
        trace('protected identity loaded')
        class SecureMachine(MacAnisette):
            def _load_identity(self):return saved.get('identity') or super()._load_identity()
            def _save_identity(self):pass
            def _load_store(self):
                for name,value in saved.get('store',{}).items():
                    if '/' in name or '\\' in name or name=='adi.pb':continue
                    self.adi.stubs.files[STORE_DIR+'/'+name]=bytearray(base64.b64decode(value,validate=True))
            def _save_store(self):
                record={'identity':self.identity,'store':{name.rsplit('/',1)[1]:base64.b64encode(bytes(value)).decode() for name,value in self.adi.stubs.files.items() if name.startswith(STORE_DIR+'/') and not name.endswith('/adi.pb')}}
                temp=protected.with_suffix('.tmp');temp.write_bytes(protect(json.dumps(record).encode()));temp.replace(protected)
        class AppleRedirects(urllib.request.HTTPRedirectHandler):
            def redirect_request(self,req,fp,code,msg,headers,newurl):return super().redirect_request(req,fp,code,msg,headers,apple_url(newurl))
        class VerifiedGSA(GSA):
            def _open(self,url,body,*,client_time):
                apple_url(url)
                return super()._open(url,body,client_time=client_time)
        machine=SecureMachine(state)
        trace('emulator created')
        service=VerifiedGSA(Device(machine.identity['device_id'],machine.identity['client_info'],machine.identity['local_user_uuid'],machine.identity['serial']),timeout=12)
        service._ctx=ssl.create_default_context()
        service._ctx.load_verify_locations(cadata=ssl.DER_cert_to_PEM_cert((ROOT/'assets/apple_root.cer').read_bytes()))
        # urlopen's default redirect handler is replaced in this isolated helper process.
        opener=urllib.request.build_opener(urllib.request.HTTPSHandler(context=service._ctx),AppleRedirects())
        original_open=urllib.request.urlopen
        urllib.request.urlopen=lambda url,*a,**kw:opener.open(url,timeout=kw.get('timeout',12))
        try:
            if not machine.is_provisioned():
                if saved:raise ValueError('Saved Apple identity could not be restored')
                machine.provision(service)
            trace('machine provisioned')
            if request.get('operation')=='resync':
                sim=base64.b64decode(request['sim'],validate=True)
                if not sim or len(sim)>65536:raise ValueError('Invalid Apple synchronization payload')
                reply=machine.adi.synchronize(DS_ID,sim)
                if reply.ret!=0:raise ValueError('Local Apple synchronization failed')
                service.load_urlbag()
                response=service.sync_machine(base64.b64encode(reply.outputs['mid']).decode(),base64.b64encode(reply.outputs['srm']).decode(),machine.identity['routing'])
                if response.get('Status',{}).get('ec',0)!=0:raise ValueError('Apple synchronization was refused')
                machine._save_store()
            headers=machine.headers();headers['X-Apple-Locale']='en_US'
            trace('headers generated')
            return {'headers':headers,'client_info':machine.identity['client_info'],'user_agent':'akd/1.0 CFNetwork/1404.0.5 Darwin/22.3.0'}
        finally:urllib.request.urlopen=original_open

def main():
    global TRACE_SINK
    pipe=os.environ.get('DIRECTSIDE_AUTH_PIPE')
    wire=None
    if pipe:
        if not pipe.startswith('\\\\.\\pipe\\DirectSide-auth-') or len(pipe)>100:return 2
        wire=open(pipe,'r+b',buffering=0)
    elif sys.stdin is None or sys.stdout is None:return 2
    watchdog=threading.Timer(80,lambda:os._exit(124));watchdog.daemon=True;watchdog.start()
    trace('helper started')
    try:
        request=json.loads((wire if wire else sys.stdin.buffer).readline(100000))
        if wire and request.get('diagnostics'):TRACE_SINK=lambda stage:wire.write((json.dumps({'stage':stage})+'\n').encode())
        value=run(request)
        if wire:wire.write((json.dumps(value)+'\n').encode())
        else:print(json.dumps(value),flush=True)
        return 0
    except BaseException as error:
        # Raw library errors can contain provisioning responses: never print them.
        message='Local Apple authentication helper failed ('+type(error).__name__+').'
        if wire:wire.write((json.dumps({'error':message})+'\n').encode())
        elif sys.stderr is not None:print(message,file=sys.stderr)
        return 1
    finally:
        watchdog.cancel()
        if wire:wire.close()

if __name__=='__main__':sys.exit(main())
