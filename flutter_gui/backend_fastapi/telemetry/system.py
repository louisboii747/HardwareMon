from fastapi import APIRouter
import glob
import os
import requests
import json
import platform
import re
import shutil
import subprocess
import psutil
from database.database import get_data_dir

router = APIRouter()

LHM_URL = "http://127.0.0.1:8085/data.json"
IS_WINDOWS = platform.system() == "Windows"


def default_stats():
    return {
        "cpu": 0,
        "cpu_temp": 0,
        "cpu_power": 0,
        "cpu_clock": 0,
        "ram": 0,
        "ram_used": 0,
        "ram_available": 0,
        "ram_total": 0,
        "gpu_temp": 0,
        "cpu_name": "Unknown CPU",
        "gpu_name": "Unknown GPU",
        "gpu_usage": 0,
        "gpu_power": 0,
        "gpu_vram_used": 0,
    }


def find_sensor(node, text):
    results = []

    if isinstance(node, dict):
        if node.get("Text") == text:
            results.append(node)

        for child in node.get("Children", []):
            results.extend(find_sensor(child, text))

    return results


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
    stats = default_stats()

    memory = psutil.virtual_memory()
    cpu_freq = psutil.cpu_freq()

    stats["cpu"] = int(psutil.cpu_percent(interval=0.1))
    stats["cpu_temp"] = read_linux_cpu_temp()
    stats["cpu_clock"] = round(cpu_freq.current, 1) if cpu_freq else 0
    stats["ram"] = int(memory.percent)
    stats["ram_used"] = round(memory.used / 1024 / 1024 / 1024, 1)
    stats["ram_available"] = round(memory.available / 1024 / 1024 / 1024, 1)
    stats["ram_total"] = round(memory.total / 1024 / 1024 / 1024, 1)
    stats["cpu_name"] = read_linux_cpu_name()
    stats.update(collect_linux_gpu_stats())

    return stats


def collect_stats():
    if not IS_WINDOWS:
        return collect_linux_stats()

    stats = default_stats()

    try:
        response = requests.get(LHM_URL, timeout=2)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print(f"LibreHardwareMonitor data unavailable: {e}")
        return stats

    with open(get_data_dir() / "lhm_data.json", "w") as f:
        json.dump(data, f, indent=2)

    # CPU name
    cpu_nodes = find_sensor(data, "12th Gen Intel Core i7-12700KF")
    if cpu_nodes:
        stats["cpu_name"] = cpu_nodes[0]["Text"]

    # GPU name
    gpu_nodes = find_sensor(data, "NVIDIA GeForce RTX 2070")
    if gpu_nodes:
        stats["gpu_name"] = gpu_nodes[0]["Text"]

    # CPU usage
    cpu_load = find_sensor(data, "CPU Total")
    if cpu_load:
        value = cpu_load[0].get("Value", "0 %")
        stats["cpu"] = int(parse_sensor_number(value))

    # CPU temperature
    cpu_package = find_sensor(data, "CPU Package")
    temps = [x for x in cpu_package if x.get("Type") == "Temperature"]
    if temps:
        value = temps[0].get("Value", "0 °C")
        stats["cpu_temp"] = int(parse_sensor_number(value))

    # CPU power
    cpu_package_power = find_sensor(data, "CPU Package")
    powers = [x for x in cpu_package_power if x.get("Type") == "Power"]
    if powers:
        value = powers[0].get("Value", "0 W")
        stats["cpu_power"] = parse_sensor_number(value)

    # CPU clock
    cpu_core_clock = find_sensor(data, "P-Core #1")
    clocks = [x for x in cpu_core_clock if x.get("Type") == "Clock"]
    if clocks:
        value = clocks[0].get("Value", "0 MHz")
        stats["cpu_clock"] = parse_sensor_number(value)

    # RAM usage
    ram_load = find_sensor(data, "Memory")
    if ram_load:
        value = ram_load[-1].get("Value", "0 %")
        stats["ram"] = int(parse_sensor_number(value))

    # RAM used
    ram_used_node = find_sensor(data, "Memory Used")
    if ram_used_node:
        value = ram_used_node[0].get("Value", "0 GB")
        stats["ram_used"] = parse_sensor_number(value)

    # RAM available
    ram_available_node = find_sensor(data, "Memory Available")
    if ram_available_node:
        value = ram_available_node[0].get("Value", "0 GB")
        stats["ram_available"] = parse_sensor_number(value)

    # GPU usage
    gpu_core_load = find_sensor(data, "GPU Core")
    loads = [x for x in gpu_core_load if x.get("Type") == "Load"]

    if loads:
        value = loads[0].get("Value", "0 %")
        stats["gpu_usage"] = int(parse_sensor_number(value))

    # GPU power
    gpu_package_power = find_sensor(data, "GPU Package")
    powers = [x for x in gpu_package_power if x.get("Type") == "Power"]

    if powers:
        value = powers[0].get("Value", "0 W")
        stats["gpu_power"] = parse_sensor_number(value)

    # GPU VRAM used
    gpu_memory_used = find_sensor(data, "GPU Memory Used")
    if gpu_memory_used:
        value = gpu_memory_used[0].get("Value", "0 MB")
        stats["gpu_vram_used"] = round(
            parse_sensor_number(value) / 1024,
            1,
        )

    # GPU temperature
    gpu_core_temp = find_sensor(data, "GPU Core")
    temps = [x for x in gpu_core_temp if x.get("Type") == "Temperature"]

    if temps:
        value = temps[0].get("Value", "0 °C")
        stats["gpu_temp"] = int(parse_sensor_number(value))

    stats["ram_total"] = round(stats["ram_used"] + stats["ram_available"], 1)

    return stats


@router.get("/stats")
async def get_stats():
    return collect_stats()
