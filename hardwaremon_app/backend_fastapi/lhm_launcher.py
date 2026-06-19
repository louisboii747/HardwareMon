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
        response = requests.get("http://127.0.0.1:8085/data.json", timeout=1)
        if response.status_code == 200:
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

    lhm_dir = os.path.dirname(lhm_path)

    try:
        subprocess.Popen(
            [lhm_path],
            cwd=lhm_dir,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    except OSError as e:
        if getattr(e, "winerror", None) == 740:
            ctypes.windll.shell32.ShellExecuteW(None, "runas", lhm_path, None, lhm_dir, 0)
        else:
            raise

    print("Started LibreHardwareMonitor")

    for _ in range(10):
        try:
            response = requests.get("http://127.0.0.1:8085/data.json", timeout=1)
            if response.status_code == 200:
                print("LibreHardwareMonitor web server ready")
                return
        except Exception:
            pass

        time.sleep(0.5)

    print("LibreHardwareMonitor web server did not become ready")
