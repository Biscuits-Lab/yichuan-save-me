"""Run Windows graphical checks on an isolated, never-activated desktop.

Usage: python tools/run_godot_offscreen.py -- <Godot-or-exported-exe> <args...>
For pure logic tests use Godot --headless. This helper is for GPU rendering and
input tests that need a window, without creating any window on the user's screen.
It never switches the active desktop and closes its own desktop after the child.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
from pathlib import Path
import subprocess
import sys
import time
import uuid


class StartupInfo(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD), ("lpReserved", wintypes.LPWSTR),
        ("lpDesktop", wintypes.LPWSTR), ("lpTitle", wintypes.LPWSTR),
        ("dwX", wintypes.DWORD), ("dwY", wintypes.DWORD),
        ("dwXSize", wintypes.DWORD), ("dwYSize", wintypes.DWORD),
        ("dwXCountChars", wintypes.DWORD), ("dwYCountChars", wintypes.DWORD),
        ("dwFillAttribute", wintypes.DWORD), ("dwFlags", wintypes.DWORD),
        ("wShowWindow", wintypes.WORD), ("cbReserved2", wintypes.WORD),
        ("lpReserved2", ctypes.POINTER(wintypes.BYTE)),
        ("hStdInput", wintypes.HANDLE), ("hStdOutput", wintypes.HANDLE),
        ("hStdError", wintypes.HANDLE),
    ]


class ProcessInfo(ctypes.Structure):
    _fields_ = [
        ("hProcess", wintypes.HANDLE), ("hThread", wintypes.HANDLE),
        ("dwProcessId", wintypes.DWORD), ("dwThreadId", wintypes.DWORD),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--cwd", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if sys.platform != "win32":
        parser.error("This isolated-desktop launcher is Windows-only; use --headless on other platforms.")
    if not command:
        parser.error("Pass a Godot or exported executable after --.")
    executable = str(Path(command[0]).resolve())
    if not Path(executable).is_file():
        parser.error("Executable does not exist: " + executable)

    user32 = ctypes.WinDLL("user32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    user32.CreateDesktopW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
    user32.CreateDesktopW.restype = wintypes.HANDLE
    user32.CloseDesktop.argtypes = [wintypes.HANDLE]
    user32.CloseDesktop.restype = wintypes.BOOL
    kernel32.CreateProcessW.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, wintypes.BOOL, wintypes.DWORD, ctypes.c_void_p, wintypes.LPCWSTR, ctypes.POINTER(StartupInfo), ctypes.POINTER(ProcessInfo)]
    kernel32.CreateProcessW.restype = wintypes.BOOL
    kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel32.GetExitCodeProcess.restype = wintypes.BOOL
    kernel32.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel32.TerminateProcess.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    desktop_name = "YichuanOffscreen_" + uuid.uuid4().hex
    desktop = user32.CreateDesktopW(desktop_name, None, None, 0, 0x01FF, None)
    if not desktop:
        raise ctypes.WinError(ctypes.get_last_error())
    process = ProcessInfo()
    start = time.monotonic()
    try:
        startup = StartupInfo()
        startup.cb = ctypes.sizeof(startup)
        startup.lpDesktop = desktop_name
        startup.dwFlags = 1  # STARTF_USESHOWWINDOW
        startup.wShowWindow = 0  # SW_HIDE; desktop isolation also covers app-created windows.
        line = ctypes.create_unicode_buffer(subprocess.list2cmdline([executable, *command[1:]]))
        if not kernel32.CreateProcessW(executable, line, None, None, False, 0x08000000, None, str(Path(args.cwd).resolve()), ctypes.byref(startup), ctypes.byref(process)):
            raise ctypes.WinError(ctypes.get_last_error())
        print("Running on an isolated desktop; the active desktop is unchanged.", flush=True)
        while kernel32.WaitForSingleObject(process.hProcess, 500) == 258:
            if time.monotonic() - start > args.timeout:
                kernel32.TerminateProcess(process.hProcess, 124)
                kernel32.WaitForSingleObject(process.hProcess, 5000)
                raise TimeoutError("Offscreen check exceeded its time limit.")
        code = wintypes.DWORD()
        if not kernel32.GetExitCodeProcess(process.hProcess, ctypes.byref(code)):
            raise ctypes.WinError(ctypes.get_last_error())
        print(f"Offscreen process exited {code.value} in {time.monotonic() - start:.1f}s.")
        return code.value
    finally:
        # Only this launcher's child can be terminated; never touch other apps.
        if process.hProcess:
            active = wintypes.DWORD()
            if kernel32.GetExitCodeProcess(process.hProcess, ctypes.byref(active)) and active.value == 259:
                kernel32.TerminateProcess(process.hProcess, 124)
                kernel32.WaitForSingleObject(process.hProcess, 5000)
        if process.hThread:
            kernel32.CloseHandle(process.hThread)
        if process.hProcess:
            kernel32.CloseHandle(process.hProcess)
        user32.CloseDesktop(desktop)


if __name__ == "__main__":
    sys.exit(main())
