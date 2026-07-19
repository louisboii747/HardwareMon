from __future__ import annotations

import platform
import socket
from typing import Any

import psutil
from fastapi import APIRouter
from telemetry.storage import get_storage_snapshot

router = APIRouter(prefix="/inventory", tags=["inventory"])


def _cpu() -> dict[str, Any]:
    frequency = psutil.cpu_freq()
    return {
        "name": platform.processor() or "Unknown CPU",
        "physical_cores": psutil.cpu_count(logical=False),
        "logical_cores": psutil.cpu_count(logical=True),
        "max_frequency_mhz": round(frequency.max, 1) if frequency else None,
    }


def _memory() -> dict[str, Any]:
    value = psutil.virtual_memory()
    return {"total_bytes": value.total, "modules": []}


def _network() -> list[dict[str, Any]]:
    statistics = psutil.net_if_stats()
    return [
        {
            "name": name,
            "up": value.isup,
            "speed_mbps": value.speed if value.speed >= 0 else None,
        }
        for name, value in sorted(statistics.items())
    ]


@router.get("")
async def hardware_inventory():
    """Return honest cross-platform inventory data without guessing.

    Detailed Windows device providers can extend the stable category lists
    later without changing the client contract.
    """
    storage = await get_storage_snapshot()
    return {
        "hostname": socket.gethostname(),
        "cpu": _cpu(),
        "gpu": [],
        "motherboard": None,
        "bios": None,
        "memory": _memory(),
        "storage": storage.get("drives", []),
        "network_adapters": _network(),
        "audio_devices": [],
        "usb_devices": [],
        "monitors": [],
        "operating_system": {
            "name": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "architecture": platform.machine(),
        },
        "provider_status": {
            "gpu": "telemetry-provider",
            "motherboard": "planned",
            "bios": "maintenance-provider",
            "ram_modules": "planned",
            "audio": "planned",
            "usb": "planned",
            "monitors": "planned",
        },
    }
