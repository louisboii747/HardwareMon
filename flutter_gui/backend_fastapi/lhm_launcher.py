import os
import sys
import time
import platform
import subprocess
import requests
import ctypes

IS_WINDOWS = platform.system() == "Windows"


def get_base_path():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)

    return os.path.dirname(os.path.abspath(__file__))


def start_lhm():
    if not IS_WINDOWS:
        return

    # Already running?
    try:
        requests.get("http://127.0.0.1:8085/data.json", timeout=1)
        print("LibreHardwareMonitor already running")
        return

    except Exception:
        pass

    base = get_base_path()

    # Candidate locations
    possible_paths = [
        os.path.join(base, "third_party", "LibreHardwareMonitor", "LibreHardwareMonitor.exe"),
        os.path.join(
            base, "_internal", "third_party", "LibreHardwareMonitor", "LibreHardwareMonitor.exe"
        ),
    ]

    lhm_path = next((p for p in possible_paths if os.path.exists(p)), None)

    print(f"Base path: {base}")
    print(f"LHM path: {lhm_path}")

    if not lhm_path:
        print("LibreHardwareMonitor not found")
        return

    try:
        subprocess.Popen([lhm_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    except OSError as e:
        if getattr(e, "winerror", None) == 740:
            ctypes.windll.shell32.ShellExecuteW(None, "runas", lhm_path, None, None, 0)
        else:
            raise

    print("Started LibreHardwareMonitor")

    time.sleep(2)
