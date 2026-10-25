import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui'))
import apple_usb

class AppleUSBRecoveryTests(unittest.TestCase):
    def test_target_is_only_apple_composite_not_a_hub_or_usb_interface(self):
        target=r'USB\VID_05AC&PID_12A8\fixture'
        self.assertTrue(apple_usb.recovery_target(target,'Apple Mobile Device USB Composite Device','usbccgp'))
        for instance in [r'USB\VID_1234&PID_12A8\fixture',r'USB\VID_05AC&PID_12A8&MI_00\fixture','*',target+'"']:
            self.assertFalse(apple_usb.recovery_target(instance,'Apple Mobile Device USB Composite Device','usbccgp'))
        self.assertFalse(apple_usb.recovery_target(target,'USB Root Hub','usbccgp'))
    def test_recovery_refuses_missing_or_ambiguous_hardware(self):
        for targets in [[],['one','two']]:
            with patch.object(apple_usb,'present_apple_usb',return_value=targets),patch.object(apple_usb.subprocess,'run') as run:
                self.assertEqual(apple_usb.restart_present_apple_usb(),2);run.assert_not_called()
    def test_scoped_restart_has_no_shell_or_global_device_scan(self):
        with patch.object(apple_usb,'present_apple_usb',return_value=['fixture']),patch.dict(apple_usb.os.environ,{'SystemRoot':r'C:\Windows'}),patch.object(apple_usb.subprocess,'run') as run:
            run.return_value.returncode=0
            self.assertEqual(apple_usb.restart_present_apple_usb(),0)
            self.assertEqual(run.call_args.args[0][1:],['/restart-device','fixture'])
            self.assertFalse(run.call_args.kwargs.get('shell',False))

if __name__=='__main__':unittest.main()
