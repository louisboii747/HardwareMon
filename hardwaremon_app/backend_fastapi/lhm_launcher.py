import ctypes
import os
import platform
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

import requests

IS_WINDOWS = platform.system() == "Windows"
LHM_URL = "http://127.0.0.1:8085/data.json"


def get_base_path():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)

    return os.path.dirname(os.path.abspath(__file__))


def get_lhm_runtime_dir():
    local_app_data = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
    if local_app_data:
        return os.path.join(local_app_data, "HardwareMon", "LibreHardwareMonitor")

    return os.path.join(
        os.path.expanduser("~"),
        "AppData",
        "Local",
        "HardwareMon",
        "LibreHardwareMonitor",
    )


def prepare_lhm_runtime(source_dir):
    runtime_dir = get_lhm_runtime_dir()

    try:
        os.makedirs(os.path.dirname(runtime_dir), exist_ok=True)
        shutil.copytree(source_dir, runtime_dir, dirs_exist_ok=True)
        return runtime_dir
    except OSError as error:
        print(
            "Could not prepare the per-user LibreHardwareMonitor directory; "
            f"using the bundled directory instead: {error}",
            flush=True,
        )
        return source_dir


def configure_lhm(lhm_dir):
    config_path = os.path.join(lhm_dir, "LibreHardwareMonitor.config")

    try:
        if os.path.exists(config_path):
            tree = ET.parse(config_path)
            root = tree.getroot()
        else:
            root = ET.Element("configuration")
            tree = ET.ElementTree(root)

        settings = root.find("./appSettings")
        if settings is None:
            settings = ET.SubElement(root, "appSettings")

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
            print(
                f"Updated LibreHardwareMonitor web server configuration: {config_path}",
                flush=True,
            )
    except (OSError, ET.ParseError) as error:
        print(
            f"Could not update LibreHardwareMonitor configuration: {error}",
            flush=True,
        )


def lhm_is_ready(timeout=1):
    try:
        response = requests.get(LHM_URL, timeout=timeout)
        return response.status_code == 200
    except requests.RequestException:
        return False


def start_lhm():
    if not IS_WINDOWS or os.environ.get("HARDWAREMON_DISABLE_LHM") == "1":
        return

    # Already running?
    if lhm_is_ready():
        print("LibreHardwareMonitor already running", flush=True)
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

    print(f"Base path: {base}", flush=True)
    print(f"Bundled LHM path: {lhm_path}", flush=True)

    if not lhm_path:
        print("LibreHardwareMonitor not found", flush=True)
        return

    lhm_dir = prepare_lhm_runtime(os.path.dirname(lhm_path))
    lhm_path = os.path.join(lhm_dir, "LibreHardwareMonitor.exe")
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
            result = ctypes.windll.shell32.ShellExecuteW(None, "runas", lhm_path, None, lhm_dir, 0)
            if result <= 32:
                print(
                    f"Could not elevate LibreHardwareMonitor (ShellExecuteW result {result})",
                    flush=True,
                )
                return
        else:
            raise

    print(f"Started LibreHardwareMonitor from: {lhm_path}", flush=True)

    for _ in range(20):
        if lhm_is_ready():
            print("LibreHardwareMonitor web server ready", flush=True)
            return

        if process is not None and process.poll() is not None:
            print(
                "LibreHardwareMonitor exited before its web server became ready "
                f"(exit code {process.returncode})",
                flush=True,
            )
            return

        time.sleep(0.5)

    print(
        "LibreHardwareMonitor web server did not become ready; "
        "HardwareMon will use fallback telemetry",
        flush=True,
    )
