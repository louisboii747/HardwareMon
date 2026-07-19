from __future__ import annotations

import hashlib
import os
import platform
import tempfile
import time
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/optimization", tags=["optimization"])

_MAX_TEMP_FILES = 50_000
_startup_entry_cache: dict[str, dict[str, Any]] = {}


class StartupToggleRequest(BaseModel):
    enabled: bool


def _entry_id(source: str, name: str) -> str:
    raw = f"{source}\0{name}".encode("utf-8", errors="ignore")
    return hashlib.sha256(raw).hexdigest()[:20]


def _impact_for(name: str, command: str) -> str:
    value = f"{name} {command}".lower()
    if any(
        token in value
        for token in (
            "game",
            "launcher",
            "teams",
            "discord",
            "steam",
            "creative cloud",
            "onedrive",
            "dropbox",
        )
    ):
        return "high"
    if any(token in value for token in ("update", "helper", "tray", "security", "driver")):
        return "low"
    return "medium"


def _startup_entry(
    *,
    source: str,
    name: str,
    command: str,
    publisher: str,
    enabled: bool,
    can_toggle: bool,
    detail: str,
    metadata: dict[str, Any],
) -> dict[str, Any]:
    identifier = _entry_id(source, name)
    entry = {
        "id": identifier,
        "name": name,
        "publisher": publisher,
        "command": command,
        "impact": _impact_for(name, command),
        "enabled": enabled,
        "can_toggle": can_toggle,
        "detail": detail,
    }
    _startup_entry_cache[identifier] = {
        **metadata,
        "can_toggle": can_toggle,
    }
    return entry


def _windows_startup_apps() -> list[dict[str, Any]]:
    import winreg

    entries: list[dict[str, Any]] = []
    run_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
    disabled_path = r"Software\HardwareMon\DisabledStartupApps"

    def enumerate_key(
        root: int,
        path: str,
        *,
        source: str,
        enabled: bool,
        can_toggle: bool,
        publisher: str,
    ) -> None:
        try:
            key = winreg.OpenKey(root, path, 0, winreg.KEY_READ)
        except OSError:
            return
        with key:
            index = 0
            while True:
                try:
                    name, command, _ = winreg.EnumValue(key, index)
                except OSError:
                    break
                index += 1
                entries.append(
                    _startup_entry(
                        source=source,
                        name=name,
                        command=str(command),
                        publisher=publisher,
                        enabled=enabled,
                        can_toggle=can_toggle,
                        detail=(
                            "Managed for the current Windows user."
                            if can_toggle
                            else "Machine-wide startup entries are read-only."
                        ),
                        metadata={
                            "platform": "windows",
                            "name": name,
                            "command": str(command),
                            "enabled": enabled,
                        },
                    )
                )

    enumerate_key(
        winreg.HKEY_CURRENT_USER,
        run_path,
        source="windows-user-run",
        enabled=True,
        can_toggle=True,
        publisher="Current user",
    )
    enumerate_key(
        winreg.HKEY_CURRENT_USER,
        disabled_path,
        source="windows-user-disabled",
        enabled=False,
        can_toggle=True,
        publisher="Current user",
    )
    enumerate_key(
        winreg.HKEY_LOCAL_MACHINE,
        run_path,
        source="windows-machine-run",
        enabled=True,
        can_toggle=False,
        publisher="System-wide",
    )
    return entries


def _read_desktop_entry(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    except OSError:
        return {}
    return values


def _linux_startup_apps() -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    user_dir = (
        Path(
            os.environ.get(
                "XDG_CONFIG_HOME",
                str(Path.home() / ".config"),
            )
        )
        / "autostart"
    )
    system_dirs = [
        Path(item) / "autostart"
        for item in os.environ.get("XDG_CONFIG_DIRS", "/etc/xdg").split(":")
        if item
    ]

    seen: set[str] = set()
    for directory, is_user in [(user_dir, True), *[(item, False) for item in system_dirs]]:
        if not directory.exists():
            continue
        for path in sorted(directory.glob("*.desktop")):
            if not is_user and path.name in seen:
                continue
            values = _read_desktop_entry(path)
            if not values:
                continue
            seen.add(path.name)
            hidden = values.get("Hidden", "false").lower() == "true"
            autostart_enabled = values.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
            name = values.get("Name", path.stem)
            command = values.get("Exec", "Unavailable")
            entries.append(
                _startup_entry(
                    source=f"linux-{'user' if is_user else 'system'}:{path}",
                    name=name,
                    command=command,
                    publisher="User session" if is_user else "Desktop environment",
                    enabled=not hidden and autostart_enabled,
                    can_toggle=True,
                    detail=(
                        "Managed through your XDG autostart folder."
                        if is_user
                        else "A user override will be created; system files stay untouched."
                    ),
                    metadata={
                        "platform": "linux",
                        "path": str(path),
                        "user_dir": str(user_dir),
                        "is_user": is_user,
                        "filename": path.name,
                        "name": name,
                        "command": command,
                        "generated_override": (values.get("X-HardwareMon-Override") == "true"),
                    },
                )
            )
    return entries


def _startup_apps() -> list[dict[str, Any]]:
    _startup_entry_cache.clear()
    if platform.system() == "Windows":
        return _windows_startup_apps()
    if platform.system() == "Linux":
        return _linux_startup_apps()
    return []


def _set_windows_startup(metadata: dict[str, Any], enabled: bool) -> None:
    import winreg

    name = metadata["name"]
    command = metadata["command"]
    run_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
    disabled_path = r"Software\HardwareMon\DisabledStartupApps"
    source_path = disabled_path if enabled else run_path
    destination_path = run_path if enabled else disabled_path

    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, destination_path) as destination:
        winreg.SetValueEx(destination, name, 0, winreg.REG_SZ, command)
    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            source_path,
            0,
            winreg.KEY_SET_VALUE,
        ) as source:
            winreg.DeleteValue(source, name)
    except OSError:
        pass


def _set_desktop_flag(path: Path, enabled: bool) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    replacement = f"Hidden={'false' if enabled else 'true'}"
    changed = False
    for index, line in enumerate(lines):
        if line.strip().startswith("Hidden="):
            lines[index] = replacement
            changed = True
            break
    if not changed:
        lines.append(replacement)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _set_linux_startup(metadata: dict[str, Any], enabled: bool) -> None:
    source = Path(metadata["path"])
    user_dir = Path(metadata["user_dir"])
    is_user = bool(metadata["is_user"])
    if is_user:
        if metadata.get("generated_override") and enabled:
            source.unlink(missing_ok=True)
            return
        _set_desktop_flag(source, enabled)
        return

    user_dir.mkdir(parents=True, exist_ok=True)
    override = user_dir / metadata["filename"]
    if enabled:
        if override.exists():
            values = _read_desktop_entry(override)
            if values.get("X-HardwareMon-Override") == "true":
                override.unlink()
            else:
                _set_desktop_flag(override, True)
        return

    override.write_text(
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={metadata['name']}\n"
        f"Exec={metadata['command']}\n"
        "Hidden=true\n"
        "X-HardwareMon-Override=true\n",
        encoding="utf-8",
    )


def _directory_size(path: Path) -> tuple[int, int, bool]:
    total = 0
    files = 0
    truncated = False
    if not path.exists():
        return total, files, truncated

    try:
        for root, _, names in os.walk(path):
            for name in names:
                if files >= _MAX_TEMP_FILES:
                    truncated = True
                    return total, files, truncated
                files += 1
                try:
                    total += (Path(root) / name).stat().st_size
                except OSError:
                    continue
    except OSError:
        pass
    return total, files, truncated


def _temporary_files() -> dict[str, Any]:
    candidates: list[tuple[str, Path]] = [("System temporary files", Path(tempfile.gettempdir()))]
    if platform.system() == "Windows":
        local = os.environ.get("LOCALAPPDATA")
        if local:
            candidates.append(("Windows temporary files", Path(local) / "Temp"))
    elif platform.system() == "Linux":
        candidates.extend(
            [
                ("Shared temporary files", Path("/var/tmp")),
                ("User cache", Path.home() / ".cache"),
            ]
        )

    unique: dict[str, tuple[str, Path]] = {}
    for label, path in candidates:
        unique[str(path.resolve(strict=False))] = (label, path)

    total = 0
    files = 0
    truncated = False
    locations = []
    for label, path in unique.values():
        size, count, partial = _directory_size(path)
        total += size
        files += count
        truncated = truncated or partial
        locations.append(
            {
                "label": label,
                "path": str(path),
                "size_bytes": size,
                "file_count": count,
            }
        )
    locations.sort(key=lambda item: item["size_bytes"], reverse=True)
    return {
        "estimated_bytes": total,
        "file_count": files,
        "truncated": truncated,
        "locations": locations,
    }


def _read_text(path: Path) -> str | None:
    try:
        value = path.read_text(encoding="utf-8", errors="replace").strip()
        return value or None
    except OSError:
        return None


def _maintenance_facts() -> dict[str, Any]:
    """Return conservative, read-only maintenance evidence.

    Missing values stay null instead of being guessed. This keeps the UI useful
    on unsupported hardware and leaves room for driver and backup providers.
    """
    try:
        import psutil

        boot_time = float(psutil.boot_time())
        battery = psutil.sensors_battery()
    except (ImportError, OSError, RuntimeError):
        boot_time = time.time()
        battery = None

    bios_vendor = None
    bios_version = None
    bios_date = None
    if platform.system() == "Linux":
        dmi = Path("/sys/class/dmi/id")
        bios_vendor = _read_text(dmi / "bios_vendor")
        bios_version = _read_text(dmi / "bios_version")
        bios_date = _read_text(dmi / "bios_date")

    uptime_seconds = max(0, int(time.time() - boot_time))
    return {
        "boot_time": boot_time,
        "uptime_seconds": uptime_seconds,
        "restart_recommended": uptime_seconds >= 14 * 24 * 60 * 60,
        "bios": {
            "vendor": bios_vendor,
            "version": bios_version,
            "date": bios_date,
        },
        "battery": None
        if battery is None
        else {
            "percent": round(float(battery.percent), 1),
            "plugged_in": bool(battery.power_plugged),
            "seconds_left": (int(battery.secsleft) if battery.secsleft >= 0 else None),
        },
        "providers": {
            "driver_status": "planned",
            "backup_status": "planned",
            "restore_points": "planned",
        },
    }


@router.get("")
async def get_optimization_snapshot():
    startup = _startup_apps()
    enabled = [item for item in startup if item["enabled"]]
    impact_weight = {"low": 1, "medium": 4, "high": 8}
    penalty = sum(impact_weight.get(item["impact"], 3) for item in enabled)
    startup_score = max(20, min(100, 100 - penalty))
    return {
        "platform": platform.system(),
        "startup_score": startup_score,
        "startup_apps": startup,
        "temporary_files": _temporary_files(),
        "maintenance": _maintenance_facts(),
        "capabilities": {
            "startup_toggle": platform.system() in {"Windows", "Linux"},
            "gaming_mode": True,
            "cleanup": False,
        },
    }


@router.patch("/startup/{entry_id}")
async def set_startup_enabled(entry_id: str, request: StartupToggleRequest):
    _startup_apps()
    metadata = _startup_entry_cache.get(entry_id)
    if metadata is None:
        raise HTTPException(status_code=404, detail="Startup entry was not found.")
    if not metadata.get("can_toggle"):
        raise HTTPException(
            status_code=409,
            detail="This machine-wide startup entry is read-only.",
        )

    try:
        if metadata["platform"] == "windows":
            _set_windows_startup(metadata, request.enabled)
        elif metadata["platform"] == "linux":
            _set_linux_startup(metadata, request.enabled)
        else:
            raise HTTPException(
                status_code=409,
                detail="Startup controls are unavailable on this platform.",
            )
    except (OSError, PermissionError) as error:
        raise HTTPException(
            status_code=409,
            detail=f"Unable to change this startup entry: {error}",
        ) from error

    return {"status": "ok", "enabled": request.enabled}
