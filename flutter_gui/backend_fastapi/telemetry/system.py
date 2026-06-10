from fastapi import APIRouter
import requests

router = APIRouter()

LHM_URL = "http://127.0.0.1:8085/data.json"


def find_sensor(node, text):
    results = []

    if isinstance(node, dict):
        if node.get("Text") == text:
            results.append(node)

        for child in node.get("Children", []):
            results.extend(find_sensor(child, text))

    return results


@router.get("/stats")
async def get_stats():
    data = requests.get(LHM_URL).json()

    import json

    with open("lhm_data.json", "w") as f:
        json.dump(data, f, indent=2)

    cpu_name = "Unknown CPU"
    gpu_name = "Unknown GPU"

    cpu_usage = 0
    ram_usage = 0
    gpu_temp = 0
    gpu_usage = 0
    gpu_power = 0
    gpu_vram_used = 0

    cpu_temp = 0
    cpu_power = 0
    cpu_clock = 0

    ram_used = 0
    ram_available = 0

    # CPU name
    cpu_nodes = find_sensor(data, "12th Gen Intel Core i7-12700KF")
    if cpu_nodes:
        cpu_name = cpu_nodes[0]["Text"]

    # GPU name
    gpu_nodes = find_sensor(data, "NVIDIA GeForce RTX 2070")
    if gpu_nodes:
        gpu_name = gpu_nodes[0]["Text"]

    # CPU usage
    cpu_load = find_sensor(data, "CPU Total")
    if cpu_load:
        value = cpu_load[0].get("Value", "0 %")
        cpu_usage = int(float(value.replace("%", "").strip()))

    # CPU temperature
    cpu_package = find_sensor(data, "CPU Package")
    temps = [x for x in cpu_package if x.get("Type") == "Temperature"]
    if temps:
        value = temps[0].get("Value", "0 °C")
        cpu_temp = int(float(value.replace("°C", "").strip()))

    # CPU power
    cpu_package_power = find_sensor(data, "CPU Package")
    powers = [x for x in cpu_package_power if x.get("Type") == "Power"]
    if powers:
        value = powers[0].get("Value", "0 W")
        cpu_power = float(value.replace("W", "").strip())

    # CPU clock
    cpu_core_clock = find_sensor(data, "P-Core #1")
    clocks = [x for x in cpu_core_clock if x.get("Type") == "Clock"]
    if clocks:
        value = clocks[0].get("Value", "0 MHz")
        cpu_clock = float(value.replace("MHz", "").strip())

    # RAM usage
    ram_load = find_sensor(data, "Memory")
    if ram_load:
        value = ram_load[-1].get("Value", "0 %")
        ram_usage = int(float(value.replace("%", "").strip()))

    # RAM used
    ram_used_node = find_sensor(data, "Memory Used")
    if ram_used_node:
        value = ram_used_node[0].get("Value", "0 GB")
        ram_used = float(value.replace("GB", "").strip())

    # RAM available
    ram_available_node = find_sensor(data, "Memory Available")
    if ram_available_node:
        value = ram_available_node[0].get("Value", "0 GB")
        ram_available = float(value.replace("GB", "").strip())

    # GPU usage
    gpu_core_load = find_sensor(data, "GPU Core")
    loads = [x for x in gpu_core_load if x.get("Type") == "Load"]

    if loads:
        value = loads[0].get("Value", "0 %")
        gpu_usage = int(float(value.replace("%", "").strip()))

    # GPU power
    gpu_package_power = find_sensor(data, "GPU Package")
    powers = [x for x in gpu_package_power if x.get("Type") == "Power"]

    if powers:
        value = powers[0].get("Value", "0 W")
        gpu_power = float(value.replace("W", "").strip())

        # GPU VRAM used
        gpu_memory_used = find_sensor(data, "GPU Memory Used")

        if gpu_memory_used:
            value = gpu_memory_used[0].get("Value", "0 MB")
            gpu_vram_used = round(
                float(value.replace("MB", "").strip()) / 1024,
                1,
            )

    # GPU temp
    gpu_core_temp = find_sensor(data, "GPU Core")
    temps = [x for x in gpu_core_temp if x.get("Type") == "Temperature"]

    if temps:
        value = temps[0].get("Value", "0 °C")
        gpu_temp = int(float(value.replace("°C", "").strip()))

        return {
            "cpu": cpu_usage,
            "cpu_temp": cpu_temp,
            "cpu_power": cpu_power,
            "cpu_clock": cpu_clock,
            "ram": ram_usage,
            "ram_used": ram_used,
            "ram_available": ram_available,
            "ram_total": round(ram_used + ram_available, 1),
            "gpu_temp": gpu_temp,
            "cpu_name": cpu_name,
            "gpu_name": gpu_name,
            "gpu_usage": gpu_usage,
            "gpu_power": gpu_power,
            "gpu_vram_used": gpu_vram_used,
        }
