"""Keep Windows' native taskbar icons explicit for the frameless Qt window."""
import ctypes
from ctypes import wintypes


class WindowsWindowIcon:
    def __init__(self, window, path):
        self.window = window
        self.user = ctypes.WinDLL('user32', use_last_error=True)
        self.user.LoadImageW.argtypes = [wintypes.HINSTANCE, wintypes.LPCWSTR,
                                        wintypes.UINT, ctypes.c_int, ctypes.c_int, wintypes.UINT]
        self.user.LoadImageW.restype = wintypes.HANDLE
        self.user.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT,
                                          ctypes.c_size_t, ctypes.c_ssize_t]
        self.user.SendMessageW.restype = ctypes.c_ssize_t
        self.user.DestroyIcon.argtypes = [wintypes.HANDLE]
        self.user.DestroyIcon.restype = wintypes.BOOL
        self.handles = []
        for size in (32, 16):
            handle = self.user.LoadImageW(None, str(path), 1, size, size, 0x10)
            if not handle:
                self.close()
                raise OSError('Could not load the Windows application icon.')
            self.handles.append(handle)
        self.apply()
        window.visibleChanged.connect(self.apply)

    def apply(self, *_):
        hwnd = int(self.window.winId())
        for kind, handle in zip((1, 0), self.handles):
            self.user.SendMessageW(hwnd, 0x0080, kind, handle)  # WM_SETICON

    def verified(self):
        hwnd = int(self.window.winId())
        return len(self.handles) == 2 and all(
            self.user.SendMessageW(hwnd, 0x007F, kind, 0) == handle  # WM_GETICON
            for kind, handle in zip((1, 0), self.handles))

    def close(self):
        for handle in self.handles:
            self.user.DestroyIcon(handle)
        self.handles.clear()
