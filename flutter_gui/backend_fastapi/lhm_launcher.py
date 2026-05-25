import os
import sys
import time
import platform
import subprocess
import requests

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

    lhm_path = os.path.join(
        base,
        "third_party",
        "LibreHardwareMonitor",
        "LibreHardwareMonitor.exe"
    )

    if not os.path.exists(lhm_path):
        print("LibreHardwareMonitor.exe not found")
        return

    subprocess.Popen(
        [lhm_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    print("Started LibreHardwareMonitor")

    time.sleep(2)