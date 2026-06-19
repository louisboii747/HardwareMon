import os
import sys
import time
import platform
import subprocess
import requests
import ctypes
import xml.etree.ElementTree as ET

IS_WINDOWS = platform.system() == "Windows"
LHM_URL = "http://127.0.0.1:8085/data.json"


def get_base_path():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)

    return os.path.dirname(os.path.abspath(__file__))


def configure_lhm(lhm_dir):
    config_path = os.path.join(lhm_dir, "LibreHardwareMonitor.config")
    if not os.path.exists(config_path):
        return

    try:
        tree = ET.parse(config_path)
        settings = tree.getroot().find("./appSettings")
        if settings is None:
            return

        desired_values = {
            "runWebServerMenuItem": "true",
            "listenerIp": "127.0.0.1",
            "listenerPort": "8085",
            "authenticationEnabled": "false",
        }

        changed = False
        entries = {entry.get("key"): entry for entry in settings.findall("add")}

        for key, value in desired_values.items():
            entry = entries.get(key)
            if entry is None:
                ET.SubElement(settings, "add", key=key, value=value)
                changed = True
            elif entry.get("value") != value:
                entry.set("value", value)
                changed = True

        if changed:
            tree.write(config_path, encoding="utf-8", xml_declaration=True)
            print("Updated LibreHardwareMonitor web server configuration")
    except (OSError, ET.ParseError) as error:
        print(f"Could not update LibreHardwareMonitor configuration: {error}")


def lhm_is_ready(timeout=1):
    try:
        response = requests.get(LHM_URL, timeout=timeout)
        return response.status_code == 200
    except requests.RequestException:
        return False


def start_lhm():
    if not IS_WINDOWS:
        return

    # Already running?
    if lhm_is_ready():
        print("LibreHardwareMonitor already running")
        return

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
    configure_lhm(lhm_dir)
    process = None

    try:
        process = subprocess.Popen(
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

    for _ in range(20):
        if lhm_is_ready():
            print("LibreHardwareMonitor web server ready")
            return

        if process is not None and process.poll() is not None:
            print(
                "LibreHardwareMonitor exited before its web server became ready "
                f"(exit code {process.returncode})"
            )
            return

        time.sleep(0.5)

    print(
        "LibreHardwareMonitor web server did not become ready; "
        "HardwareMon will use fallback telemetry"
    )
