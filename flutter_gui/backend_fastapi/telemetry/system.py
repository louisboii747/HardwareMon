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

    cpu_name = "Unknown CPU"
    gpu_name = "Unknown GPU"

    cpu_usage = 0
    ram_usage = 0
    gpu_temp = 0

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

    # RAM usage
    ram_load = find_sensor(data, "Memory")
    if ram_load:
        value = ram_load[-1].get("Value", "0 %")
        ram_usage = int(float(value.replace("%", "").strip()))

    # GPU temp
    gpu_core_temp = find_sensor(data, "GPU Core")
    temps = [
        x for x in gpu_core_temp
        if x.get("Type") == "Temperature"
    ]

    if temps:
        value = temps[0].get("Value", "0 °C")
        gpu_temp = int(float(value.replace("°C", "").strip()))

    return {
        "cpu": cpu_usage,
        "ram": ram_usage,
        "gpu_temp": gpu_temp,
        "cpu_name": cpu_name,
        "gpu_name": gpu_name,
    }