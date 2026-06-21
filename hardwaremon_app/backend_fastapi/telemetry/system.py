from fastapi import APIRouter
import glob
import os
import requests
import json
import platform
import re
import shutil
import subprocess
import time
import psutil
from database.database import get_data_dir
from process_utils import hidden_process_kwargs

router = APIRouter()

LHM_URL = "http://127.0.0.1:8085/data.json"
IS_WINDOWS = platform.system() == "Windows"
_last_lhm_error_log = 0


def read_disk_usage():
    try:
        path = f"{os.environ.get('SystemDrive', 'C:')}\\" if IS_WINDOWS else "/"
        return int(psutil.disk_usage(path).percent)
    except (OSError, PermissionError):
        return 0


def read_cpu_name():
    if IS_WINDOWS:
        try:
            import winreg

            key_path = r"HARDWARE\DESCRIPTION\System\CentralProcessor\0"
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                value, _ = winreg.QueryValueEx(key, "ProcessorNameString")
                if value:
                    return str(value).strip()
        except (ImportError, OSError):
            pass

    return platform.processor() or "Unknown CPU"


def collect_basic_stats():
    memory = psutil.virtual_memory()
    cpu_freq = psutil.cpu_freq()

    return {
        "cpu": int(psutil.cpu_percent(interval=0.1)),
        "cpu_temp": 0,
        "cpu_power": 0,
        "cpu_clock": round(cpu_freq.current, 1) if cpu_freq else 0,
        "ram": int(memory.percent),
        "ram_used": round(memory.used / 1024 / 1024 / 1024, 1),
        "ram_available": round(memory.available / 1024 / 1024 / 1024, 1),
        "ram_total": round(memory.total / 1024 / 1024 / 1024, 1),
        "disk": read_disk_usage(),
        "gpu_temp": 0,
        "cpu_name": read_cpu_name(),
        "gpu_name": "Unknown GPU",
        "gpu_usage": 0,
        "gpu_power": 0,
        "gpu_vram_used": 0,
    }


def default_stats():
    return collect_basic_stats()


def find_sensor(node, text):
    results = []

    if isinstance(node, dict):
        if node.get("Text") == text:
            results.append(node)

        for child in node.get("Children", []):
            results.extend(find_sensor(child, text))

    return results


def iter_nodes(node):
    if not isinstance(node, dict):
        return

    yield node
    for child in node.get("Children", []):
        yield from iter_nodes(child)


def find_hardware(data, prefixes):
    for node in iter_nodes(data):
        hardware_id = str(node.get("HardwareId", "")).lower()
        if any(hardware_id.startswith(prefix) for prefix in prefixes):
            return node

    return None


def find_typed_sensor(node, sensor_type, names=()):
    if node is None:
        return None

    normalized_names = {name.lower() for name in names}

    for candidate in iter_nodes(node):
        if candidate.get("Type") != sensor_type:
            continue

        if not normalized_names or str(candidate.get("Text", "")).lower() in normalized_names:
            return candidate

    return None


def sensor_value(node, default=0):
    if node is None:
        return default

    return parse_sensor_number(node.get("Value"), default)


def parse_sensor_number(value, default=0):
    if value is None:
        return default

    text = str(value).strip()
    if not text or text == "-":
        return default

    match = re.search(r"-?\d+(?:[.,]\d+)?", text)
    if not match:
        return default

    try:
        return float(match.group(0).replace(",", "."))
    except ValueError:
        return default


def read_linux_cpu_name():
    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as f:
            for line in f:
                if line.lower().startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass

    return platform.processor() or "Unknown CPU"


def read_linux_cpu_temp():
    try:
        for entries in psutil.sensors_temperatures().values():
            for sensor in entries:
                if sensor.current is not None:
                    return int(sensor.current)
    except (AttributeError, OSError):
        pass

    return 0


def read_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def read_number_file(path, scale=1):
    value = parse_sensor_number(read_file(path), None)
    if value is None:
        return None

    return value / scale


def collect_nvidia_smi_stats():
    if not shutil.which("nvidia-smi"):
        return {}

    query = ",".join(
        [
            "name",
            "utilization.gpu",
            "temperature.gpu",
            "power.draw",
            "memory.used",
        ]
    )

    try:
        result = subprocess.run(
            [
                "nvidia-smi",
                f"--query-gpu={query}",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            check=True,
            text=True,
            timeout=2,
            **hidden_process_kwargs(),
        )
    except (OSError, subprocess.SubprocessError):
        return {}

    line = next((x for x in result.stdout.splitlines() if x.strip()), "")
    values = [x.strip() for x in line.split(",")]

    if len(values) < 5:
        return {}

    return {
        "gpu_name": values[0] or "NVIDIA GPU",
        "gpu_usage": int(parse_sensor_number(values[1])),
        "gpu_temp": int(parse_sensor_number(values[2])),
        "gpu_power": parse_sensor_number(values[3]),
        "gpu_vram_used": round(parse_sensor_number(values[4]) / 1024, 1),
    }


def find_amd_hwmon_dirs(device_path):
    return [
        path
        for path in glob.glob(os.path.join(device_path, "hwmon", "hwmon*"))
        if os.path.isdir(path)
    ]


def read_amd_gpu_name(device_path):
    for name_path in glob.glob(os.path.join(device_path, "hwmon", "hwmon*", "name")):
        name = read_file(name_path)
        if name:
            return f"AMD {name}"

    return "AMD GPU"


def collect_amd_sysfs_stats():
    for device_path in glob.glob("/sys/class/drm/card*/device"):
        vendor = read_file(os.path.join(device_path, "vendor")).lower()
        if vendor != "0x1002":
            continue

        stats = {"gpu_name": read_amd_gpu_name(device_path)}

        usage = read_number_file(os.path.join(device_path, "gpu_busy_percent"))
        if usage is not None:
            stats["gpu_usage"] = int(usage)

        vram_used = read_number_file(os.path.join(device_path, "mem_info_vram_used"), 1024**3)
        if vram_used is not None:
            stats["gpu_vram_used"] = round(vram_used, 1)

        for hwmon_dir in find_amd_hwmon_dirs(device_path):
            temp = read_number_file(os.path.join(hwmon_dir, "temp1_input"), 1000)
            if temp is not None:
                stats["gpu_temp"] = int(temp)
                break

        for hwmon_dir in find_amd_hwmon_dirs(device_path):
            power = read_number_file(os.path.join(hwmon_dir, "power1_average"), 1000000)
            if power is None:
                power = read_number_file(os.path.join(hwmon_dir, "power1_input"), 1000000)

            if power is not None:
                stats["gpu_power"] = round(power, 1)
                break

        return stats

    return {}


def collect_linux_gpu_stats():
    return collect_nvidia_smi_stats() or collect_amd_sysfs_stats()


def collect_linux_stats():
    stats = collect_basic_stats()
    stats["cpu_temp"] = read_linux_cpu_temp()
    stats["cpu_name"] = read_linux_cpu_name()
    stats.update(collect_linux_gpu_stats())

    return stats


def collect_stats():
    if not IS_WINDOWS:
        return collect_linux_stats()

    stats = collect_basic_stats()
    stats.update(collect_nvidia_smi_stats())

    try:
        response = requests.get(LHM_URL, timeout=2)
        response.raise_for_status()
        data = response.json()
    except (requests.RequestException, ValueError) as error:
        global _last_lhm_error_log
        now = time.monotonic()
        if now - _last_lhm_error_log >= 60:
            print(
                "LibreHardwareMonitor data unavailable; using fallback telemetry: "
                f"{error}"
            )
            _last_lhm_error_log = now
        return stats

    try:
        with open(get_data_dir() / "lhm_data.json", "w", encoding="utf-8") as file:
            json.dump(data, file, indent=2)
    except OSError:
        pass

    cpu = find_hardware(data, ("/cpu/", "/intelcpu/", "/amdcpu/"))
    gpu = find_hardware(data, ("/gpu-nvidia/", "/gpu-amd/", "/gpu-intel/"))

    if cpu is not None:
        stats["cpu_name"] = cpu.get("Text") or stats["cpu_name"]
        stats["cpu"] = int(
            sensor_value(find_typed_sensor(cpu, "Load", ("CPU Total",)), stats["cpu"])
        )
        stats["cpu_temp"] = int(
            sensor_value(
                find_typed_sensor(cpu, "Temperature", ("CPU Package", "Core Max")),
                stats["cpu_temp"],
            )
        )
        stats["cpu_power"] = sensor_value(
            find_typed_sensor(cpu, "Power", ("CPU Package",)),
            stats["cpu_power"],
        )
        stats["cpu_clock"] = sensor_value(
            find_typed_sensor(
                cpu,
                "Clock",
                ("P-Core #1", "Core #1", "CPU Core #1"),
            ),
            stats["cpu_clock"],
        )

    if gpu is not None:
        stats["gpu_name"] = gpu.get("Text") or stats["gpu_name"]
        stats["gpu_usage"] = int(
            sensor_value(
                find_typed_sensor(gpu, "Load", ("GPU Core", "GPU D3D 3D")),
                stats["gpu_usage"],
            )
        )
        stats["gpu_temp"] = int(
            sensor_value(
                find_typed_sensor(gpu, "Temperature", ("GPU Core", "GPU Hot Spot")),
                stats["gpu_temp"],
            )
        )
        stats["gpu_power"] = sensor_value(
            find_typed_sensor(gpu, "Power", ("GPU Package", "GPU Power")),
            stats["gpu_power"],
        )

        vram_used = find_typed_sensor(gpu, "SmallData", ("GPU Memory Used",))
        if vram_used is None:
            vram_used = find_typed_sensor(gpu, "Data", ("GPU Memory Used",))
        if vram_used is not None:
            stats["gpu_vram_used"] = round(sensor_value(vram_used) / 1024, 1)

    return stats


@router.get("/stats")
async def get_stats():
    return collect_stats()
