from fastapi import APIRouter, HTTPException
import os
import platform
import psutil

router = APIRouter()

_OPERATING_SYSTEM = platform.system()

_WINDOWS_SYSTEM_ACCOUNTS = {
    "system",
    "local service",
    "network service",
    "nt authority\\system",
    "nt authority\\local service",
    "nt authority\\network service",
}

_WINDOWS_SYSTEM_ACCOUNT_PREFIXES = (
    "font driver host\\",
    "iis apppool\\",
    "nt service\\",
    "window manager\\",
)

_WINDOWS_SYSTEM_PROCESS_NAMES = {
    "csrss.exe",
    "dwm.exe",
    "fontdrvhost.exe",
    "lsass.exe",
    "memory compression",
    "registry",
    "services.exe",
    "secure system",
    "sihost.exe",
    "smss.exe",
    "svchost.exe",
    "system",
    "system idle process",
    "wininit.exe",
    "winlogon.exe",
}

_LINUX_SYSTEM_USERS = {
    "_apt",
    "backup",
    "bin",
    "daemon",
    "irc",
    "list",
    "lp",
    "mail",
    "man",
    "news",
    "nobody",
    "proxy",
    "root",
    "sync",
    "sys",
    "uucp",
    "www-data",
}

_LINUX_SYSTEM_PROCESS_NAMES = {
    "at-spi-bus-launcher",
    "at-spi2-registryd",
    "dbus-broker",
    "dbus-daemon",
    "gnome-shell",
    "pipewire",
    "pipewire-pulse",
    "plasmashell",
    "pulseaudio",
    "systemd",
    "systemd-journald",
    "systemd-logind",
    "systemd-oomd",
    "systemd-resolved",
    "systemd-timesyncd",
    "systemd-udevd",
    "wireplumber",
    "xdg-desktop-portal",
}

_LINUX_SYSTEM_PROCESS_PREFIXES = (
    "gvfs",
    "kworker",
    "ksoftirqd",
    "migration",
    "rcu_",
    "watchdog",
)


def _is_system_process(proc: psutil.Process, name: str, username: str) -> bool:
    """Classify OS services and kernel processes without hiding desktop apps."""
    if proc.pid == os.getpid():
        return True

    normalized_name = name.strip().lower()
    normalized_user = username.replace("/", "\\").strip().lower()

    if _OPERATING_SYSTEM == "Windows":
        return (
            proc.pid <= 4
            or normalized_user in _WINDOWS_SYSTEM_ACCOUNTS
            or normalized_user.startswith(_WINDOWS_SYSTEM_ACCOUNT_PREFIXES)
            or normalized_name in _WINDOWS_SYSTEM_PROCESS_NAMES
        )

    if _OPERATING_SYSTEM == "Linux":
        try:
            if proc.uids().real < 1000:
                return True
        except (AttributeError, psutil.AccessDenied, psutil.NoSuchProcess):
            if normalized_user == "root":
                return True

        return (
            normalized_user in _LINUX_SYSTEM_USERS
            or normalized_user.startswith("systemd-")
            or normalized_name in _LINUX_SYSTEM_PROCESS_NAMES
            or normalized_name.startswith(_LINUX_SYSTEM_PROCESS_PREFIXES)
        )

    return False


@router.get("/processes")
def get_processes():
    processes = []

    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
        try:
            info = proc.info
            if info["name"] in ["System Idle Process", "System"]:
                continue

            username = proc.username()
            ram_mb = info["memory_info"].rss / 1024 / 1024 if info["memory_info"] else 0

            processes.append(
                {
                    "pid": info["pid"],
                    "name": info["name"],
                    "cpu": round(info["cpu_percent"] / psutil.cpu_count(), 1),
                    "ram": round(ram_mb, 1),
                    "is_system": _is_system_process(
                        proc,
                        info["name"] or "",
                        username,
                    ),
                }
            )

        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    processes.sort(key=lambda x: x["cpu"], reverse=True)

    return processes


@router.post("/kill/{pid}")
def kill_process(pid: int):
    try:
        process = psutil.Process(pid)

        process.terminate()

        try:
            process.wait(timeout=3)
        except psutil.TimeoutExpired:
            process.kill()

        return {"success": True, "pid": pid}

    except psutil.NoSuchProcess:
        raise HTTPException(status_code=404, detail="Process not found")

    except psutil.AccessDenied:
        raise HTTPException(status_code=403, detail="Access denied")
