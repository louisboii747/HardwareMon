from __future__ import annotations

import os
import platform
import re
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional

import psutil

from process_utils import hidden_process_kwargs


def collect_hardware_profile(data_dir: Path) -> Dict[str, Any]:
    """Collect comparison fields without privileged or identifying probes.

    Serial numbers, network addresses, usernames, installed applications, and
    file names are intentionally never collected here. Missing optional fields
    stay null so unsupported platforms remain fully usable.
    """

    system = platform.system()
    profile: Dict[str, Any] = {
        "cpu_cores": int(psutil.cpu_count(logical=False) or 0),
        "cpu_threads": int(psutil.cpu_count(logical=True) or 0),
        "gpu_model": None,
        "ram_speed_mhz": None,
        "storage_type": None,
        "operating_system": _operating_system(system),
    }

    try:
        from telemetry.system import collect_stats

        gpu = str(collect_stats().get("gpu_name") or "").strip()
        if gpu and gpu.lower() not in {"unknown", "unknown gpu"}:
            profile["gpu_model"] = gpu
    except Exception:
        pass

    try:
        from telemetry.storage import collect_storage_stats

        drives = collect_storage_stats().get("drives") or []
        drive = _drive_for_path(drives, data_dir)
        if drive:
            profile["storage_type"] = classify_storage_type(drive)
    except Exception:
        pass

    if system == "Windows":
        _fill_windows_details(profile)
    elif system == "Darwin":
        _fill_macos_details(profile, data_dir)

    return profile


def classify_storage_type(drive: Dict[str, Any]) -> Optional[str]:
    interface = str(drive.get("interface_type") or "").lower()
    media = str(drive.get("media_type") or "").lower()
    model = str(drive.get("model") or "").lower()
    combined = " ".join((interface, media, model))
    rotational = drive.get("rotational")

    if "nvme" in combined or "pci-express" in combined:
        return "NVMe"
    if "solid state" in combined or "ssd" in combined or rotational in (0, False, "0"):
        return "SSD"
    if "hdd" in combined or "hard disk" in combined or rotational in (1, True, "1"):
        return "HDD"
    if "sata" in combined or "ata" in combined:
        return "SATA"
    return interface.upper() if interface and interface != "unavailable" else None


def _drive_for_path(drives: Any, data_dir: Path) -> Optional[Dict[str, Any]]:
    target = os.path.normcase(str(data_dir.resolve()))
    matches = []
    for drive in drives:
        if not isinstance(drive, dict):
            continue
        mount = os.path.normcase(str(drive.get("mount_point") or ""))
        if mount and target.startswith(mount):
            matches.append((len(mount), drive))
    if matches:
        return max(matches, key=lambda item: item[0])[1]
    return next(
        (drive for drive in drives if isinstance(drive, dict) and not drive.get("removable")),
        None,
    )


def _operating_system(system: str) -> str:
    if system == "Darwin":
        return "macOS"
    return system or "Unknown"


def _run(command: list[str], timeout: float = 8.0) -> str:
    completed = subprocess.run(
        command,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
        shell=False,
        **hidden_process_kwargs(),
    )
    return completed.stdout.strip() if completed.returncode == 0 else ""


def _fill_windows_details(profile: Dict[str, Any]) -> None:
    if not profile.get("gpu_model"):
        gpu = _run(
            [
                "powershell.exe",
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                "Get-CimInstance Win32_VideoController | Select-Object -First 1 -ExpandProperty Name",
            ]
        )
        if gpu:
            profile["gpu_model"] = gpu.splitlines()[0].strip()

    speed = _run(
        [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "Get-CimInstance Win32_PhysicalMemory | Where-Object Speed | Measure-Object Speed -Minimum | Select-Object -ExpandProperty Minimum",
        ]
    )
    match = re.search(r"\d+", speed)
    if match:
        profile["ram_speed_mhz"] = int(match.group())


def _fill_macos_details(profile: Dict[str, Any], data_dir: Path) -> None:
    details = _run(
        [
            "system_profiler",
            "SPDisplaysDataType",
            "SPMemoryDataType",
            "-detailLevel",
            "mini",
        ],
        timeout=12,
    )
    if not profile.get("gpu_model"):
        match = re.search(r"Chipset Model:\s*(.+)", details)
        if match:
            profile["gpu_model"] = match.group(1).strip()
    speed = re.search(r"Speed:\s*(\d+)\s*MHz", details, flags=re.IGNORECASE)
    if speed:
        profile["ram_speed_mhz"] = int(speed.group(1))

    if not profile.get("storage_type"):
        disk = _run(["diskutil", "info", str(data_dir)], timeout=8)
        profile["storage_type"] = classify_storage_type(
            {"interface_type": disk, "model": disk}
        )
