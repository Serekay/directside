"""Scoped recovery of one present Apple USB composite device. No device IDs logged."""
import ctypes
import os
import re
import subprocess
import sys
import socket
import struct
import plistlib
import time
from pathlib import Path

def recovery_target(instance, description, service):
    return (bool(re.fullmatch(r'USB\\VID_05AC&PID_[0-9A-F]{4}\\[^\\"\r\n]+', instance, re.I))
            and description == 'Apple Mobile Device USB Composite Device'
            and service.casefold() == 'usbccgp')

def present_apple_usb():
    if os.name != 'nt': return []
    from ctypes import wintypes as w
    class Device(ctypes.Structure):
        _fields_=[('size',w.DWORD),('guid',ctypes.c_byte*16),('instance',w.DWORD),('reserved',ctypes.c_size_t)]
    api=ctypes.WinDLL('setupapi',use_last_error=True)
    api.SetupDiGetClassDevsW.argtypes=[ctypes.c_void_p,w.LPCWSTR,w.HWND,w.DWORD]
    api.SetupDiGetClassDevsW.restype=w.HANDLE
    api.SetupDiEnumDeviceInfo.argtypes=[w.HANDLE,w.DWORD,ctypes.POINTER(Device)]
    api.SetupDiGetDeviceRegistryPropertyW.argtypes=[w.HANDLE,ctypes.POINTER(Device),w.DWORD,ctypes.c_void_p,ctypes.c_void_p,w.DWORD,ctypes.c_void_p]
    api.SetupDiGetDeviceInstanceIdW.argtypes=[w.HANDLE,ctypes.POINTER(Device),w.LPWSTR,w.DWORD,ctypes.c_void_p]
    api.SetupDiDestroyDeviceInfoList.argtypes=[w.HANDLE]
    handle=api.SetupDiGetClassDevsW(None,'USB',None,6) # PRESENT | ALLCLASSES
    if handle == ctypes.c_void_p(-1).value: raise ctypes.WinError(ctypes.get_last_error())
    found=[]
    try:
        for index in range(4096):
            info=Device();info.size=ctypes.sizeof(info)
            if not api.SetupDiEnumDeviceInfo(handle,index,ctypes.byref(info)):
                if ctypes.get_last_error()==259: break
                raise ctypes.WinError(ctypes.get_last_error())
            instance=ctypes.create_unicode_buffer(1024)
            if not api.SetupDiGetDeviceInstanceIdW(handle,ctypes.byref(info),instance,len(instance),None): continue
            def prop(key):
                value=ctypes.create_unicode_buffer(1024)
                return value.value if api.SetupDiGetDeviceRegistryPropertyW(handle,ctypes.byref(info),key,None,value,ctypes.sizeof(value),None) else ''
            description=prop(12) or prop(0)
            if recovery_target(instance.value,description,prop(4)):found.append(instance.value)
    finally:api.SetupDiDestroyDeviceInfoList(handle)
    return found

def restart_present_apple_usb():
    """Revalidate in the elevated process; never restart a hub or multiple phones."""
    targets=present_apple_usb()
    if len(targets)!=1:return 2
    # Restart the stuck Apple service as well as the scoped USB device. A running
    # service alone does not prove that it can enumerate phones.
    script="""$ErrorActionPreference='Stop'
$svc=Get-Service -Name 'Apple Mobile Device Service'
if ($svc.Status -ne 'Stopped') {
 Stop-Service -InputObject $svc
 $svc.WaitForStatus('Stopped',[TimeSpan]::FromSeconds(15))
}
Start-Service -InputObject $svc
$svc.WaitForStatus('Running',[TimeSpan]::FromSeconds(15))
"""
    service=subprocess.run([str(Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'),
        '-NoProfile','-NonInteractive','-Command',script],stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NO_WINDOW,timeout=40)
    if service.returncode:return 3
    result=subprocess.run([str(Path(os.environ['SystemRoot'])/'System32/pnputil.exe'),
        '/restart-device',targets[0]],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW,timeout=45)
    return result.returncode

def apple_devices_available():
    """Read usbmux's real enumeration without logging device identifiers."""
    def read(stream,length):
        data=b''
        while len(data)<length:
            chunk=stream.recv(length-len(data))
            if not chunk:raise OSError('Apple connection closed')
            data+=chunk
        return data
    with socket.create_connection(('127.0.0.1',27015),2) as stream:
        stream.settimeout(2)
        payload=plistlib.dumps({'MessageType':'ListDevices','ClientVersionString':'DirectSide',
            'ProgName':'DirectSide','kLibUSBMuxVersion':3})
        stream.sendall(struct.pack('<IIII',16+len(payload),1,8,1)+payload)
        length,version,message,tag=struct.unpack('<IIII',read(stream,16))
        if not 16<=length<=1024*1024 or version!=1 or message!=8 or tag!=1:return False
        devices=plistlib.loads(read(stream,length-16)).get('DeviceList',[])
        return any(d.get('Properties',{}).get('ConnectionType')=='USB' for d in devices)

def recover_apple_usb(event):
    from components import elevated, ElevationCancelled
    if len(present_apple_usb())!=1:
        event({'type':'usb_recovered','ok':False});return
    args=['--recover-apple-usb']
    if not getattr(sys,'frozen',False):args.insert(0,str(Path(__file__).with_name('desktop.py')))
    try:result=elevated(sys.executable,subprocess.list2cmdline(args))
    except ElevationCancelled:
        event({'type':'usb_recovered','ok':False,'cancelled':True});return
    if result:
        event({'type':'usb_recovered','ok':False});return
    event({'type':'usb_repair_waiting'})
    deadline=time.monotonic()+25
    while time.monotonic()<deadline:
        try:
            if apple_devices_available():
                event({'type':'usb_recovered','ok':True});return
        except (OSError,ValueError,plistlib.InvalidFileException):pass
        time.sleep(1)
    event({'type':'usb_recovered','ok':False})
