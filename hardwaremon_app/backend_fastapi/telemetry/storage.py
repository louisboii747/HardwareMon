from __future__ import annotations

import heapq
import json
import math
import os
import platform
import random
import shutil
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import psutil
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from database.database import get_connection, get_data_dir


router = APIRouter(prefix="/storage", tags=["storage"])

_state_lock = threading.Lock()
_previous_io: dict[str, tuple[float, int, int]] = {}
_peak_read_bps = 0.0
_peak_write_bps = 0.0
_metadata_cache: tuple[float, dict[str, dict[str, Any]]] = (0.0, {})
_jobs_lock = threading.Lock()
_scan_jobs: dict[str, dict[str, Any]] = {}
_benchmark_jobs: dict[str, dict[str, Any]] = {}

_ignored_filesystems = {
    "",
    "autofs",
    "cgroup",
    "cgroup2",
    "configfs",
    "debugfs",
    "devpts",
    "devtmpfs",
    "fusectl",
    "hugetlbfs",
    "mqueue",
    "overlay",
    "proc",
    "pstore",
    "securityfs",
    "squashfs",
    "sysfs",
    "tmpfs",
    "tracefs",
}


class DriveRequest(BaseModel):
    drive_id: str = Field(min_length=1, max_length=1024)


class BenchmarkRequest(DriveRequest):
    mode: str = Field(default="quick", pattern="^(quick|full)$")


def _run_command(command: list[str], timeout: float = 8.0) -> str:
    creation_flags = 0
    if platform.system() == "Windows":
        creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    completed = subprocess.run(
        command,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=timeout,
        check=False,
        shell=False,
        creationflags=creation_flags,
    )
    return completed.stdout.strip()


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def _windows_metadata() -> dict[str, dict[str, Any]]:
    script = r"""
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=2 OR DriveType=3" | ForEach-Object {
  $volume = $_
  $partition = Get-CimAssociatedInstance -InputObject $volume -Association Win32_LogicalDiskToPartition -ErrorAction SilentlyContinue | Select-Object -First 1
  $disk = if ($partition) { Get-CimAssociatedInstance -InputObject $partition -Association Win32_DiskDriveToDiskPartition -ErrorAction SilentlyContinue | Select-Object -First 1 }
  [pscustomobject]@{
    mount_point = "$($volume.DeviceID)\"
    label = $volume.VolumeName
    filesystem = $volume.FileSystem
    device = $disk.DeviceID
    model = $disk.Model
    serial = $disk.SerialNumber
    interface_type = $disk.InterfaceType
    io_key = if ($null -ne $disk.Index) { "PhysicalDrive$($disk.Index)" } else { $null }
    disk_number = $disk.Index
    health_status = $disk.Status
    removable = ($volume.DriveType -eq 2)
  }
}
$physical = Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
  $counter = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
  [pscustomobject]@{
    device_id = $_.DeviceId
    serial = $_.SerialNumber
    model = $_.FriendlyName
    health_status = [string]$_.HealthStatus
    interface_type = [string]$_.BusType
    temperature = $counter.Temperature
  }
}
[pscustomobject]@{ logical = @($logical); physical = @($physical) } | ConvertTo-Json -Depth 5 -Compress
"""
    try:
        raw = _run_command(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
            timeout=12,
        )
        payload = json.loads(raw) if raw else {}
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return {}

    physical_by_id = {
        str(item.get("device_id")): item
        for item in _as_list(payload.get("physical"))
        if isinstance(item, dict) and item.get("device_id") is not None
    }
    result: dict[str, dict[str, Any]] = {}
    for item in _as_list(payload.get("logical")):
        if not isinstance(item, dict):
            continue
        mount = str(item.get("mount_point") or "")
        physical = physical_by_id.get(str(item.get("disk_number")), {})
        temperature = physical.get("temperature")
        item["temperature"] = (
            float(temperature) if isinstance(temperature, (int, float)) else None
        )
        item["health_status"] = (
            physical.get("health_status") or item.get("health_status")
        )
        item["interface_type"] = (
            physical.get("interface_type") or item.get("interface_type")
        )
        item["model"] = physical.get("model") or item.get("model")
        item["serial"] = physical.get("serial") or item.get("serial")
        result[os.path.normcase(mount)] = item
    return result


def _flatten_lsblk(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    flattened: list[dict[str, Any]] = []

    def visit(node: dict[str, Any], parent: dict[str, Any] | None = None) -> None:
        merged = dict(node)
        if parent is not None:
            for key in ("model", "serial", "tran", "path", "kname"):
                if not merged.get(key):
                    merged[key] = parent.get(key)
            merged["_physical_kname"] = (
                parent.get("_physical_kname") or parent.get("kname")
            )
            merged["_physical_path"] = (
                parent.get("_physical_path") or parent.get("path")
            )
        else:
            merged["_physical_kname"] = merged.get("kname")
            merged["_physical_path"] = merged.get("path")
        flattened.append(merged)
        for child in _as_list(node.get("children")):
            if isinstance(child, dict):
                visit(child, merged)

    for node in nodes:
        visit(node)
    return flattened


def _linux_smart_metadata(device: str) -> dict[str, Any]:
    if not device or shutil.which("smartctl") is None:
        return {}
    try:
        raw = _run_command(["smartctl", "-a", "-j", device], timeout=6)
        payload = json.loads(raw) if raw else {}
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return {}

    smart = payload.get("smart_status") or {}
    temperature = payload.get("temperature") or {}
    passed = smart.get("passed")
    return {
        "smart_status": (
            "Passed" if passed is True else "Failed" if passed is False else None
        ),
        "temperature": temperature.get("current"),
        "model": payload.get("model_name") or payload.get("product"),
        "serial": payload.get("serial_number"),
        "interface_type": (payload.get("device") or {}).get("protocol"),
    }


def _linux_metadata() -> dict[str, dict[str, Any]]:
    try:
        raw = _run_command(
            [
                "lsblk",
                "-J",
                "-b",
                "-o",
                "NAME,KNAME,PATH,PKNAME,MOUNTPOINTS,FSTYPE,LABEL,MODEL,SERIAL,TRAN,TYPE,SIZE",
            ],
            timeout=8,
        )
        payload = json.loads(raw) if raw else {}
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return {}

    nodes = _flatten_lsblk(_as_list(payload.get("blockdevices")))
    smart_cache: dict[str, dict[str, Any]] = {}
    result: dict[str, dict[str, Any]] = {}
    for item in nodes:
        mount_points = item.get("mountpoints")
        if not isinstance(mount_points, list):
            mount_points = [item.get("mountpoint")]
        physical_path = str(item.get("_physical_path") or "")
        if physical_path not in smart_cache:
            smart_cache[physical_path] = _linux_smart_metadata(physical_path)
        smart = smart_cache[physical_path]
        for mount in mount_points:
            if not mount:
                continue
            result[os.path.normcase(str(mount))] = {
                "mount_point": str(mount),
                "label": item.get("label"),
                "filesystem": item.get("fstype"),
                "device": item.get("path"),
                "model": smart.get("model") or item.get("model"),
                "serial": smart.get("serial") or item.get("serial"),
                "interface_type": smart.get("interface_type") or item.get("tran"),
                "io_key": item.get("_physical_kname") or item.get("kname"),
                "health_status": smart.get("smart_status"),
                "smart_status": smart.get("smart_status"),
                "temperature": smart.get("temperature"),
                "removable": str(item.get("tran") or "").lower() == "usb",
            }
    return result


def _platform_metadata() -> dict[str, dict[str, Any]]:
    global _metadata_cache
    now = time.monotonic()
    if now - _metadata_cache[0] < 45:
        return _metadata_cache[1]

    metadata = (
        _windows_metadata()
        if platform.system() == "Windows"
        else _linux_metadata()
    )
    _metadata_cache = (now, metadata)
    return metadata


def _health_status(
    used_percent: float,
    temperature: float | None,
    smart_status: str | None,
) -> str:
    smart = (smart_status or "").lower()
    if "fail" in smart or used_percent >= 95 or (temperature or 0) >= 65:
        return "critical"
    if used_percent >= 85 or (temperature or 0) >= 55:
        return "warning"
    return "healthy"


def _storage_score(
    used_percent: float,
    temperature: float | None,
    smart_status: str | None,
) -> int:
    score = 100.0
    if used_percent > 70:
        score -= min(35, (used_percent - 70) * 1.4)
    if temperature is not None and temperature > 45:
        score -= min(30, (temperature - 45) * 1.5)
    smart = (smart_status or "").lower()
    if "fail" in smart:
        score -= 55
    elif smart and "pass" not in smart and "healthy" not in smart and "ok" not in smart:
        score -= 8
    return max(0, min(100, round(score)))


def _insights_for_drive(drive: dict[str, Any]) -> list[dict[str, str]]:
    insights: list[dict[str, str]] = []
    used = float(drive["used_percent"])
    temperature = drive.get("temperature_c")
    smart = str(drive.get("smart_status") or "").lower()
    name = drive["label"] or drive["mount_point"]
    if used >= 90:
        insights.append(
            {
                "severity": "critical" if used >= 95 else "warning",
                "title": "Drive nearly full",
                "message": f"{name} is {used:.0f}% used. Free space soon to protect performance.",
            }
        )
    if temperature is not None and temperature >= 55:
        insights.append(
            {
                "severity": "critical" if temperature >= 65 else "warning",
                "title": "Temperature elevated",
                "message": f"{name} is reporting {temperature:.0f}°C.",
            }
        )
    if "fail" in smart:
        insights.append(
            {
                "severity": "critical",
                "title": "SMART warning",
                "message": f"{name} reported a failing health state. Back up important data.",
            }
        )
    if not insights:
        insights.append(
            {
                "severity": "healthy",
                "title": "Healthy operation",
                "message": f"{name} has comfortable capacity and no active health warnings.",
            }
        )
    return insights


def _disk_rates(io_key: str | None, counters: dict[str, Any]) -> tuple[float, float]:
    if not io_key and len(counters) == 1:
        io_key = next(iter(counters))
    if not io_key:
        return 0.0, 0.0
    counter = counters.get(io_key)
    if counter is None:
        normalized = io_key.lower().replace("\\\\.\\", "")
        counter = next(
            (
                value
                for key, value in counters.items()
                if key.lower().replace("\\\\.\\", "") == normalized
            ),
            None,
        )
    if counter is None:
        return 0.0, 0.0

    now = time.monotonic()
    read_bytes = int(getattr(counter, "read_bytes", 0))
    write_bytes = int(getattr(counter, "write_bytes", 0))
    previous = _previous_io.get(io_key)
    _previous_io[io_key] = (now, read_bytes, write_bytes)
    if previous is None:
        return 0.0, 0.0
    elapsed = max(0.001, now - previous[0])
    return (
        max(0.0, (read_bytes - previous[1]) / elapsed),
        max(0.0, (write_bytes - previous[2]) / elapsed),
    )


def collect_storage_stats() -> dict[str, Any]:
    global _peak_read_bps, _peak_write_bps
    metadata = _platform_metadata()
    try:
        counters = psutil.disk_io_counters(perdisk=True, nowrap=True) or {}
    except (OSError, RuntimeError, TypeError):
        counters = {}
    try:
        partitions = psutil.disk_partitions(all=False)
    except (OSError, RuntimeError):
        partitions = []

    seen: set[str] = set()
    drives: list[dict[str, Any]] = []
    rates_by_key: dict[str, tuple[float, float]] = {}
    with _state_lock:
        for partition in partitions:
            mount = partition.mountpoint
            normalized_mount = os.path.normcase(os.path.normpath(mount))
            if normalized_mount in seen:
                continue
            if platform.system() != "Windows" and partition.fstype.lower() in _ignored_filesystems:
                continue
            if not os.path.exists(mount):
                continue
            try:
                usage = psutil.disk_usage(mount)
            except (OSError, PermissionError):
                continue
            seen.add(normalized_mount)
            details = metadata.get(os.path.normcase(mount), {})
            io_key = details.get("io_key")
            rate_key = str(io_key or "")
            if rate_key not in rates_by_key:
                rates_by_key[rate_key] = _disk_rates(io_key, counters)
            read_bps, write_bps = rates_by_key[rate_key]
            temperature = details.get("temperature")
            if not isinstance(temperature, (int, float)) or temperature <= 0:
                temperature = None
            smart = details.get("smart_status") or details.get("health_status")
            used_percent = float(usage.percent)
            status = _health_status(used_percent, temperature, smart)
            drive = {
                "id": mount,
                "mount_point": mount,
                "label": details.get("label") or "",
                "filesystem": details.get("filesystem") or partition.fstype or "Unavailable",
                "device": details.get("device") or partition.device or "Unavailable",
                "model": (details.get("model") or "").strip() or "Unavailable",
                "serial": (details.get("serial") or "").strip() or None,
                "interface_type": (
                    str(details.get("interface_type") or "").strip() or "Unavailable"
                ),
                "total_bytes": int(usage.total),
                "used_bytes": int(usage.used),
                "free_bytes": int(usage.free),
                "used_percent": round(used_percent, 2),
                "read_bps": round(read_bps, 2),
                "write_bps": round(write_bps, 2),
                "temperature_c": round(float(temperature), 1)
                if temperature is not None
                else None,
                "health_status": status,
                "smart_status": smart or None,
                "removable": bool(details.get("removable")),
                "score": _storage_score(used_percent, temperature, smart),
            }
            drive["insights"] = _insights_for_drive(drive)
            drives.append(drive)

        total = sum(drive["total_bytes"] for drive in drives)
        used = sum(drive["used_bytes"] for drive in drives)
        free = sum(drive["free_bytes"] for drive in drives)
        read_bps = sum(rate[0] for rate in rates_by_key.values())
        write_bps = sum(rate[1] for rate in rates_by_key.values())
        _peak_read_bps = max(_peak_read_bps, read_bps)
        _peak_write_bps = max(_peak_write_bps, write_bps)

    temperatures = [
        drive["temperature_c"]
        for drive in drives
        if drive["temperature_c"] is not None
    ]
    status_order = {"healthy": 0, "warning": 1, "critical": 2}
    overall_status = max(
        (drive["health_status"] for drive in drives),
        key=lambda status: status_order[status],
        default="healthy",
    )
    insights = [
        insight
        for drive in drives
        for insight in drive["insights"]
        if insight["severity"] != "healthy"
    ]
    if not insights and drives:
        insights = [
            {
                "severity": "healthy",
                "title": "Storage systems nominal",
                "message": "All detected drives are operating within current health thresholds.",
            }
        ]

    return {
        "sampled_at": datetime.now(timezone.utc).isoformat(),
        "total_capacity": total,
        "used_capacity": used,
        "free_capacity": free,
        "used_percent": round((used / total * 100) if total else 0.0, 2),
        "read_bps": round(read_bps, 2),
        "write_bps": round(write_bps, 2),
        "peak_read_bps": round(_peak_read_bps, 2),
        "peak_write_bps": round(_peak_write_bps, 2),
        "temperature_c": round(max(temperatures), 1) if temperatures else None,
        "health_status": overall_status,
        "storage_score": (
            round(sum(drive["score"] for drive in drives) / len(drives))
            if drives
            else 0
        ),
        "insights": insights[:8],
        "drives": drives,
    }


def _detected_drive(drive_id: str) -> dict[str, Any]:
    snapshot = collect_storage_stats()
    for drive in snapshot["drives"]:
        if drive["id"] == drive_id:
            return drive
    raise HTTPException(status_code=404, detail="The selected drive is unavailable.")


def _trim_jobs(jobs: dict[str, dict[str, Any]], maximum: int = 20) -> None:
    if len(jobs) <= maximum:
        return
    completed = [
        (job.get("created_at", 0.0), job_id)
        for job_id, job in jobs.items()
        if job.get("status") in {"complete", "failed"}
    ]
    for _, job_id in sorted(completed)[: max(0, len(jobs) - maximum)]:
        jobs.pop(job_id, None)


def _scan_worker(job_id: str, drive: dict[str, Any]) -> None:
    root = Path(drive["mount_point"])
    used_bytes = max(1, int(drive["used_bytes"]))
    directory_sizes: dict[str, int] = {}
    largest_files: list[tuple[int, str]] = []
    scanned_bytes = 0
    scanned_files = 0
    errors = 0
    last_progress_update = time.monotonic()

    try:
        for current, directories, files in os.walk(root, topdown=True, followlinks=False):
            directories[:] = [
                name
                for name in directories
                if not os.path.islink(os.path.join(current, name))
                and name not in {"$Recycle.Bin", "System Volume Information"}
            ]
            current_path = Path(current)
            for filename in files:
                path = current_path / filename
                try:
                    size = path.stat().st_size
                except (OSError, PermissionError):
                    errors += 1
                    continue
                scanned_bytes += size
                scanned_files += 1
                if len(largest_files) < 100:
                    heapq.heappush(largest_files, (size, str(path)))
                elif size > largest_files[0][0]:
                    heapq.heapreplace(largest_files, (size, str(path)))

                relative_parts = path.relative_to(root).parts[:-1]
                for depth in range(1, min(3, len(relative_parts)) + 1):
                    key = str(root.joinpath(*relative_parts[:depth]))
                    directory_sizes[key] = directory_sizes.get(key, 0) + size

                now = time.monotonic()
                if scanned_files % 250 == 0 or now - last_progress_update >= 0.4:
                    with _jobs_lock:
                        job = _scan_jobs.get(job_id)
                        if job is not None:
                            job.update(
                                {
                                    "progress": min(0.99, scanned_bytes / used_bytes),
                                    "scanned_bytes": scanned_bytes,
                                    "scanned_files": scanned_files,
                                    "current_path": str(current_path),
                                }
                            )
                    last_progress_update = now

        top_directories = sorted(
            directory_sizes.items(), key=lambda item: item[1], reverse=True
        )[:80]
        nodes: dict[str, dict[str, Any]] = {}
        for path, size in top_directories:
            relative = Path(path).relative_to(root)
            if len(relative.parts) > 3:
                continue
            nodes[path] = {
                "name": Path(path).name or str(root),
                "path": path,
                "size_bytes": size,
                "percent_of_disk": round(size / used_bytes * 100, 2),
                "children": [],
            }
        tree: list[dict[str, Any]] = []
        for path, node in nodes.items():
            parent = str(Path(path).parent)
            if parent in nodes:
                nodes[parent]["children"].append(node)
            else:
                tree.append(node)
        for node in nodes.values():
            node["children"].sort(key=lambda item: item["size_bytes"], reverse=True)

        files_result = [
            {
                "name": Path(path).name,
                "path": path,
                "size_bytes": size,
                "percent_of_disk": round(size / used_bytes * 100, 3),
            }
            for size, path in sorted(largest_files, reverse=True)[:50]
        ]
        with _jobs_lock:
            _scan_jobs[job_id].update(
                {
                    "status": "complete",
                    "progress": 1.0,
                    "scanned_bytes": scanned_bytes,
                    "scanned_files": scanned_files,
                    "errors": errors,
                    "current_path": None,
                    "tree": tree[:20],
                    "largest_files": files_result,
                    "completed_at": datetime.now(timezone.utc).isoformat(),
                }
            )
    except Exception as error:
        with _jobs_lock:
            _scan_jobs[job_id].update(
                {"status": "failed", "error": str(error), "current_path": None}
            )


def _benchmark_directory(drive: dict[str, Any]) -> Path:
    root = Path(drive["mount_point"])
    candidate = root / ".hardwaremon-benchmark"
    try:
        candidate.mkdir(exist_ok=True)
        return candidate
    except (OSError, PermissionError):
        data_dir = get_data_dir()
        try:
            if root.stat().st_dev == data_dir.stat().st_dev:
                candidate = data_dir / "benchmark"
                candidate.mkdir(parents=True, exist_ok=True)
                return candidate
        except OSError:
            pass
    raise PermissionError("HardwareMon cannot create a temporary benchmark file on this drive.")


def _benchmark_worker(job_id: str, drive: dict[str, Any], mode: str) -> None:
    size_mb = 16 if mode == "quick" else 64
    random_operations = 512 if mode == "quick" else 2048
    file_path: Path | None = None
    try:
        directory = _benchmark_directory(drive)
        file_path = directory / f"benchmark-{uuid.uuid4().hex}.tmp"
        block = os.urandom(1024 * 1024)
        started = time.perf_counter()
        with file_path.open("wb", buffering=0) as handle:
            for index in range(size_mb):
                handle.write(block)
                if index % 4 == 0:
                    with _jobs_lock:
                        _benchmark_jobs[job_id]["progress"] = 0.05 + (
                            index / size_mb * 0.35
                        )
            os.fsync(handle.fileno())
        sequential_write = size_mb / max(0.001, time.perf_counter() - started)

        started = time.perf_counter()
        with file_path.open("rb", buffering=0) as handle:
            while handle.read(1024 * 1024):
                pass
        sequential_read = size_mb / max(0.001, time.perf_counter() - started)
        with _jobs_lock:
            _benchmark_jobs[job_id]["progress"] = 0.55

        file_size = size_mb * 1024 * 1024
        block_size = 4096
        offsets = [
            random.randrange(0, max(block_size, file_size - block_size), block_size)
            for _ in range(random_operations)
        ]
        random_block = os.urandom(block_size)
        started = time.perf_counter()
        with file_path.open("r+b", buffering=0) as handle:
            for offset in offsets:
                handle.seek(offset)
                handle.write(random_block)
            os.fsync(handle.fileno())
        random_write = (
            random_operations * block_size / 1024 / 1024
        ) / max(0.001, time.perf_counter() - started)

        started = time.perf_counter()
        with file_path.open("rb", buffering=0) as handle:
            for offset in reversed(offsets):
                handle.seek(offset)
                handle.read(block_size)
        random_read = (
            random_operations * block_size / 1024 / 1024
        ) / max(0.001, time.perf_counter() - started)

        with _jobs_lock:
            _benchmark_jobs[job_id].update(
                {
                    "status": "complete",
                    "progress": 1.0,
                    "results": {
                        "sequential_read_mbps": round(sequential_read, 1),
                        "sequential_write_mbps": round(sequential_write, 1),
                        "random_read_mbps": round(random_read, 1),
                        "random_write_mbps": round(random_write, 1),
                    },
                    "completed_at": datetime.now(timezone.utc).isoformat(),
                }
            )
    except Exception as error:
        with _jobs_lock:
            _benchmark_jobs[job_id].update(
                {"status": "failed", "error": str(error)}
            )
    finally:
        if file_path is not None:
            try:
                file_path.unlink(missing_ok=True)
                file_path.parent.rmdir()
            except OSError:
                pass


def _forecast(rows: list[Any]) -> dict[str, Any]:
    valid = [
        (datetime.fromisoformat(str(row["timestamp"])), float(row["capacity_percent"]))
        for row in rows
        if row["capacity_percent"] is not None
    ]
    if len(valid) < 3:
        return {"days_until_full": None, "confidence": 0.0, "trend_per_day": 0.0}
    valid.sort(key=lambda item: item[0])
    elapsed_days = (valid[-1][0] - valid[0][0]).total_seconds() / 86400
    if elapsed_days <= 0:
        return {"days_until_full": None, "confidence": 0.0, "trend_per_day": 0.0}
    trend = (valid[-1][1] - valid[0][1]) / elapsed_days
    if trend <= 0.01:
        return {
            "days_until_full": None,
            "confidence": min(1.0, len(valid) / 100),
            "trend_per_day": round(trend, 4),
        }
    days = max(0.0, (100 - valid[-1][1]) / trend)
    confidence = min(1.0, (len(valid) / 100) * min(1.0, elapsed_days / 7))
    return {
        "days_until_full": round(days, 1),
        "confidence": round(confidence, 2),
        "trend_per_day": round(trend, 4),
    }


@router.get("")
async def get_storage_snapshot():
    return collect_storage_stats()


@router.get("/history")
async def get_storage_history(
    drive_id: str | None = Query(default=None, max_length=1024),
    range_seconds: int = Query(default=3600, ge=60, le=2_592_000),
    points: int = Query(default=360, ge=30, le=1500),
):
    bucket_seconds = max(1, math.ceil(range_seconds / points))
    conn = get_connection()
    try:
        drive_clause = "AND drive_id = ?" if drive_id else ""
        parameters: list[Any] = [
            bucket_seconds,
            bucket_seconds,
            f"-{range_seconds} seconds",
        ]
        if drive_id:
            parameters.append(drive_id)
        parameters.extend([bucket_seconds, points])
        rows = conn.execute(
            f"""
            SELECT
                datetime(
                    (CAST(strftime('%s', timestamp) AS INTEGER) / ?) * ?,
                    'unixepoch'
                ) AS timestamp,
                AVG(capacity_percent) AS capacity_percent,
                {"AVG" if drive_id else "SUM"}(read_bps) AS read_bps,
                {"AVG" if drive_id else "SUM"}(write_bps) AS write_bps,
                AVG(temperature_c) AS temperature_c
            FROM storage_history
            WHERE timestamp >= datetime('now', ?)
            {drive_clause}
            GROUP BY CAST(strftime('%s', timestamp) AS INTEGER) / ?
            ORDER BY timestamp ASC
            LIMIT ?
            """,
            parameters,
        ).fetchall()
        heatmap_parameters: list[Any] = []
        heatmap_clause = ""
        if drive_id:
            heatmap_clause = "AND drive_id = ?"
            heatmap_parameters.append(drive_id)
        heatmap = conn.execute(
            f"""
            SELECT
                CAST(strftime('%w', timestamp) AS INTEGER) AS weekday,
                CAST(strftime('%H', timestamp) AS INTEGER) AS hour,
                AVG(read_bps + write_bps) AS throughput_bps
            FROM storage_history
            WHERE timestamp >= datetime('now', '-7 days')
            {heatmap_clause}
            GROUP BY weekday, hour
            """,
            heatmap_parameters,
        ).fetchall()
        return {
            "samples": [dict(row) for row in rows],
            "heatmap": [dict(row) for row in heatmap],
            "forecast": _forecast(rows) if drive_id else None,
        }
    finally:
        conn.close()


@router.post("/scan")
async def start_storage_scan(request: DriveRequest):
    drive = _detected_drive(request.drive_id)
    job_id = uuid.uuid4().hex
    with _jobs_lock:
        _trim_jobs(_scan_jobs)
        _scan_jobs[job_id] = {
            "id": job_id,
            "drive_id": request.drive_id,
            "status": "running",
            "progress": 0.0,
            "scanned_bytes": 0,
            "scanned_files": 0,
            "current_path": drive["mount_point"],
            "tree": [],
            "largest_files": [],
            "created_at": time.time(),
        }
    threading.Thread(
        target=_scan_worker,
        args=(job_id, drive),
        daemon=True,
        name=f"storage-scan-{job_id[:8]}",
    ).start()
    return {"job_id": job_id}


@router.get("/scan/{job_id}")
async def get_storage_scan(job_id: str):
    with _jobs_lock:
        job = _scan_jobs.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="Scan job not found.")
        return dict(job)


@router.post("/benchmark")
async def start_storage_benchmark(request: BenchmarkRequest):
    drive = _detected_drive(request.drive_id)
    job_id = uuid.uuid4().hex
    with _jobs_lock:
        _trim_jobs(_benchmark_jobs)
        _benchmark_jobs[job_id] = {
            "id": job_id,
            "drive_id": request.drive_id,
            "mode": request.mode,
            "status": "running",
            "progress": 0.0,
            "results": None,
            "created_at": time.time(),
        }
    threading.Thread(
        target=_benchmark_worker,
        args=(job_id, drive, request.mode),
        daemon=True,
        name=f"storage-benchmark-{job_id[:8]}",
    ).start()
    return {"job_id": job_id}


@router.get("/benchmark/{job_id}")
async def get_storage_benchmark(job_id: str):
    with _jobs_lock:
        job = _benchmark_jobs.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="Benchmark job not found.")
        return dict(job)


@router.post("/open")
async def open_storage_drive(request: DriveRequest):
    drive = _detected_drive(request.drive_id)
    path = drive["mount_point"]
    try:
        if platform.system() == "Windows":
            os.startfile(path)  # type: ignore[attr-defined]
        else:
            subprocess.Popen(
                ["xdg-open", path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
    except (OSError, subprocess.SubprocessError) as error:
        raise HTTPException(status_code=503, detail=f"Could not open drive: {error}") from error
    return {"opened": True, "path": path}
