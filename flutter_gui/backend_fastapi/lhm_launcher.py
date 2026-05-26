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

    try:
        requests.get(
            "http://127.0.0.1:8085/data.json",
            timeout=1
        )

        print("LibreHardwareMonitor already running")
        return

    except:
        pass

    base = get_base_path()

    if getattr(sys, "frozen", False):
        lhm_path = os.path.join(
            base,
            "_internal",
            "third_party",
            "LibreHardwareMonitor",
            "LibreHardwareMonitor.exe"
        )
    else:
        lhm_path = os.path.join(
            base,
            "third_party",
            "LibreHardwareMonitor",
            "LibreHardwareMonitor.exe"
        )

    if not os.path.exists(lhm_path):
        print(f"LibreHardwareMonitor not found: {lhm_path}")
        return

    try:
        subprocess.Popen(
            [lhm_path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    except OSError as e:
        if e.winerror == 740:
            ctypes.windll.shell32.ShellExecuteW(
                None,
                "runas",
                lhm_path,
                None,
                None,
                0
            )
        else:
            raise

    print("Started LibreHardwareMonitor")

    time.sleep(2)