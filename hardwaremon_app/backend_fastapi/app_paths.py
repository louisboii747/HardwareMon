from __future__ import annotations

import logging
import os
import platform
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping


logger = logging.getLogger("hardwaremon.startup")


@dataclass(frozen=True)
class AppPaths:
    data_dir: Path
    database_path: Path
    plugin_data_dir: Path
    fallback_used: bool
    source: str


def _valid_directory(value: str | None) -> Path | None:
    if not value or not value.strip():
        return None
    try:
        # Environment-provided roots are expected to be absolute. Avoid
        # expanduser here: it can call Path.home() and fail in frozen Windows
        # processes whose user-profile variables are unavailable.
        candidate = Path(value)
        if "~" in candidate.parts:
            return None
        return candidate.resolve()
    except (OSError, RuntimeError):
        return None


def resolve_app_paths(
    environment: Mapping[str, str] | None = None,
    system: str | None = None,
    temp_root: str | Path | None = None,
) -> AppPaths:
    env = os.environ if environment is None else environment
    current_system = system or platform.system()
    fallback_used = False

    portable = _valid_directory(env.get("HARDWAREMON_PORTABLE_ROOT"))
    if portable is not None:
        data_dir, source = portable, "HARDWAREMON_PORTABLE_ROOT"
    elif current_system == "Windows":
        local = _valid_directory(env.get("LOCALAPPDATA"))
        roaming = _valid_directory(env.get("APPDATA"))
        profile = _valid_directory(env.get("USERPROFILE"))
        if local is not None:
            data_dir, source = local / "HardwareMon", "LOCALAPPDATA"
        elif roaming is not None:
            data_dir, source = roaming / "HardwareMon", "APPDATA"
            fallback_used = True
        elif profile is not None:
            data_dir, source = profile / "AppData" / "Local" / "HardwareMon", "USERPROFILE"
            fallback_used = True
        else:
            root = Path(temp_root or tempfile.gettempdir()).resolve()
            data_dir, source = root / "HardwareMon", "TEMP"
            fallback_used = True
    elif current_system == "Darwin":
        home = _valid_directory(env.get("HOME"))
        if home is not None:
            data_dir, source = home / "Library" / "Application Support" / "HardwareMon", "HOME"
        else:
            data_dir, source = Path(temp_root or tempfile.gettempdir()).resolve() / "hardwaremon", "TEMP"
            fallback_used = True
    else:
        xdg = _valid_directory(env.get("XDG_DATA_HOME"))
        home = _valid_directory(env.get("HOME"))
        if xdg is not None:
            data_dir, source = xdg / "hardwaremon", "XDG_DATA_HOME"
        elif home is not None:
            data_dir, source = home / ".local" / "share" / "hardwaremon", "HOME"
        else:
            data_dir, source = Path(temp_root or tempfile.gettempdir()).resolve() / "hardwaremon", "TEMP"
            fallback_used = True

    data_dir = data_dir.resolve()
    return AppPaths(
        data_dir=data_dir,
        database_path=data_dir / "hardwaremon.db",
        plugin_data_dir=data_dir / "plugins",
        fallback_used=fallback_used,
        source=source,
    )


def ensure_app_paths(paths: AppPaths | None = None) -> AppPaths:
    resolved = paths or resolve_app_paths()
    resolved.data_dir.mkdir(parents=True, exist_ok=True)
    return resolved


def startup_diagnostics(paths: AppPaths) -> dict[str, object]:
    return {
        "frozen": bool(getattr(sys, "frozen", False)),
        "platform": platform.system(),
        "executable": str(Path(sys.executable).resolve()),
        "app_data_dir": str(paths.data_dir),
        "database_path": str(paths.database_path),
        "plugin_data_path": str(paths.plugin_data_dir),
        "fallback_used": paths.fallback_used,
        "path_source": paths.source,
    }
