from __future__ import annotations

import ipaddress
import math
import platform
import re
import socket
import statistics
import subprocess
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import psutil
from fastapi import APIRouter
from pydantic import BaseModel, Field

from process_utils import hidden_process_kwargs


router = APIRouter(prefix="/network", tags=["network"])

_state_lock = threading.Lock()
_previous_interfaces: dict[str, tuple[float, int, int]] = {}
_session_interfaces: dict[str, tuple[int, int]] = {}
_gateway_cache: tuple[float, str | None] = (0.0, None)
_virtual_markers = (
    "virtual",
    "vmware",
    "hyper-v",
    "vethernet",
    "docker",
    "wsl",
    "loopback",
    "tailscale",
    "zerotier",
    "tun",
    "tap",
    "bridge",
)
_latency_pattern = re.compile(
    r"time\s*(?P<operator>[=<])\s*(?P<value>\d+(?:[.,]\d+)?)\s*ms",
    re.IGNORECASE,
)


class PingRequest(BaseModel):
    target: str = Field(min_length=1, max_length=2048)
    count: int = Field(default=4, ge=1, le=10)
    timeout: float = Field(default=2.0, ge=0.25, le=5.0)


def normalize_target(raw_target: str) -> tuple[str, str]:
    """Return a display target and a hostname that is safe to resolve."""
    value = raw_target.strip()
    if not value:
        raise ValueError("Enter a domain, URL, or IP address.")
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        raise ValueError("The target contains unsupported control characters.")

    display_target = value
    host = value

    if "://" in value:
        try:
            parsed = urlsplit(value)
            parsed_port = parsed.port
        except ValueError as error:
            raise ValueError("The URL is not valid.") from error

        if parsed.scheme.lower() not in {"http", "https"}:
            raise ValueError("Only HTTP and HTTPS URLs are supported.")
        if parsed.username is not None or parsed.password is not None:
            raise ValueError("URLs containing credentials are not supported.")
        if not parsed.hostname:
            raise ValueError("The URL does not contain a valid host.")

        host = parsed.hostname
        display_target = value
        if parsed_port is not None and not 1 <= parsed_port <= 65535:
            raise ValueError("The URL port is outside the valid range.")
    elif any(character in value for character in "/?#@"):
        raise ValueError("Enter a full HTTP(S) URL or a host without a path.")

    host = host.strip().rstrip(".")
    if not host or len(host) > 253 or any(character.isspace() for character in host):
        raise ValueError("The host is not valid.")

    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        try:
            ascii_host = host.encode("idna").decode("ascii").lower()
        except UnicodeError as error:
            raise ValueError("The domain name is not valid.") from error

        labels = ascii_host.split(".")
        if any(
            not label
            or len(label) > 63
            or label.startswith("-")
            or label.endswith("-")
            or re.fullmatch(r"[a-z0-9-]+", label) is None
            for label in labels
        ):
            raise ValueError("The domain name is not valid.")
        host = ascii_host
    else:
        if address.is_multicast or address.is_unspecified or address.is_reserved:
            raise ValueError("That IP address cannot be tested safely.")
        host = address.compressed

    return display_target, host


def _resolve_target(host: str) -> str:
    try:
        direct_address = ipaddress.ip_address(host)
    except ValueError:
        direct_address = None

    if direct_address is not None:
        return direct_address.compressed

    try:
        results = socket.getaddrinfo(
            host,
            None,
            family=socket.AF_UNSPEC,
            type=socket.SOCK_DGRAM,
        )
    except socket.gaierror as error:
        raise ValueError("The domain could not be resolved.") from error

    addresses: list[tuple[int, str]] = []
    for family, _, _, _, sockaddr in results:
        address = sockaddr[0]
        if (family, address) not in addresses:
            addresses.append((family, address))

    if not addresses:
        raise ValueError("The domain did not resolve to an IP address.")

    addresses.sort(key=lambda item: 0 if item[0] == socket.AF_INET else 1)
    return addresses[0][1]


def _ping_command(address: str, count: int, timeout: float) -> list[str]:
    system = platform.system()
    if system == "Windows":
        return [
            "ping",
            "-n",
            str(count),
            "-w",
            str(max(250, int(timeout * 1000))),
            address,
        ]
    if system == "Darwin":
        return [
            "ping",
            "-n",
            "-c",
            str(count),
            "-W",
            str(max(250, int(timeout * 1000))),
            address,
        ]
    return [
        "ping",
        "-n",
        "-c",
        str(count),
        "-W",
        str(max(1, math.ceil(timeout))),
        address,
    ]


def _latencies_from_output(output: str) -> list[float]:
    latencies: list[float] = []
    for match in _latency_pattern.finditer(output):
        value = float(match.group("value").replace(",", "."))
        if match.group("operator") == "<":
            value = max(0.1, value / 2)
        latencies.append(round(value, 2))
    return latencies


def _jitter(latencies: list[float]) -> float:
    if len(latencies) < 2:
        return 0.0
    changes = [
        abs(current - previous)
        for previous, current in zip(latencies, latencies[1:])
    ]
    return round(statistics.fmean(changes), 2)


def ping_target(request: PingRequest) -> dict[str, Any]:
    try:
        display_target, host = normalize_target(request.target)
        resolved_host = _resolve_target(host)
    except ValueError as error:
        return {
            "target": request.target.strip(),
            "resolved_host": None,
            "reachable": False,
            "latency_ms": None,
            "average_ms": None,
            "min_ms": None,
            "max_ms": None,
            "jitter_ms": None,
            "packet_loss_percent": 100.0,
            "samples": 0,
            "sample_latencies_ms": [],
            "error": str(error),
        }

    command = _ping_command(resolved_host, request.count, request.timeout)
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=min(60.0, (request.count * request.timeout) + 3.0),
            check=False,
            shell=False,
            **hidden_process_kwargs(),
        )
        output = f"{completed.stdout}\n{completed.stderr}"
        latencies = _latencies_from_output(output)
    except FileNotFoundError:
        return {
            "target": display_target,
            "resolved_host": resolved_host,
            "reachable": False,
            "latency_ms": None,
            "average_ms": None,
            "min_ms": None,
            "max_ms": None,
            "jitter_ms": None,
            "packet_loss_percent": 100.0,
            "samples": 0,
            "sample_latencies_ms": [],
            "error": "The operating system ping utility is unavailable.",
        }
    except subprocess.TimeoutExpired:
        latencies = []

    reachable = bool(latencies)
    packet_loss = round(
        max(0.0, min(100.0, ((request.count - len(latencies)) / request.count) * 100)),
        1,
    )
    return {
        "target": display_target,
        "resolved_host": resolved_host,
        "reachable": reachable,
        "latency_ms": latencies[-1] if reachable else None,
        "average_ms": round(statistics.fmean(latencies), 2) if reachable else None,
        "min_ms": min(latencies) if reachable else None,
        "max_ms": max(latencies) if reachable else None,
        "jitter_ms": _jitter(latencies) if reachable else None,
        "packet_loss_percent": packet_loss,
        "samples": len(latencies),
        "sample_latencies_ms": latencies,
        "error": None if reachable else "The target did not reply before the timeout.",
    }


def _address_details(addresses: list[Any]) -> tuple[str | None, str | None, str | None]:
    ipv4 = None
    ipv6 = None
    mac = None
    link_family = getattr(psutil, "AF_LINK", object())
    packet_family = getattr(socket, "AF_PACKET", object())

    for address in addresses:
        if address.family == socket.AF_INET and ipv4 is None:
            ipv4 = address.address
        elif address.family == socket.AF_INET6 and ipv6 is None:
            ipv6 = address.address.split("%", 1)[0]
        elif address.family in {link_family, packet_family} and mac is None:
            mac = address.address

    return ipv4, ipv6, mac


def _is_loopback(name: str, ipv4: str | None, ipv6: str | None) -> bool:
    if name.lower().startswith(("lo", "loopback")):
        return True
    for value in (ipv4, ipv6):
        if not value:
            continue
        try:
            if ipaddress.ip_address(value).is_loopback:
                return True
        except ValueError:
            pass
    return False


def _outbound_local_ip() -> str | None:
    """Return the local IPv4 address selected by the OS default route."""
    for target in (("1.1.1.1", 53), ("8.8.8.8", 53)):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            sock.settimeout(0.25)
            sock.connect(target)
            address = sock.getsockname()[0]
            if address and not ipaddress.ip_address(address).is_loopback:
                return address
        except (OSError, ValueError):
            pass
        finally:
            sock.close()
    return None


def _interface_priority(
    interface: dict[str, Any],
    outbound_ip: str | None,
) -> tuple[int, int, int, float, int]:
    if not interface["is_up"] or interface["is_loopback"]:
        return (-1, -1, -1, -1.0, -1)

    ipv4 = interface.get("ipv4")
    routable = 0
    if ipv4:
        try:
            address = ipaddress.ip_address(ipv4)
            routable = int(
                not address.is_loopback
                and not address.is_link_local
                and not address.is_unspecified
            )
        except ValueError:
            pass

    return (
        int(bool(outbound_ip and ipv4 == outbound_ip)),
        int(not interface["is_virtual"]),
        routable,
        float(interface["download_bps"]) + float(interface["upload_bps"]),
        int(interface["bytes_received"]) + int(interface["bytes_sent"]),
    )


def _default_gateway() -> str | None:
    global _gateway_cache
    now = time.monotonic()
    if now - _gateway_cache[0] < 30:
        return _gateway_cache[1]

    gateway = None
    if platform.system() == "Linux":
        try:
            for line in Path("/proc/net/route").read_text(encoding="utf-8").splitlines()[1:]:
                fields = line.split()
                if len(fields) >= 3 and fields[1] == "00000000":
                    gateway = socket.inet_ntoa(bytes.fromhex(fields[2])[::-1])
                    break
        except (OSError, ValueError):
            pass
    elif platform.system() == "Windows":
        try:
            completed = subprocess.run(
                ["route", "PRINT", "-4", "0.0.0.0"],
                capture_output=True,
                text=True,
                errors="replace",
                timeout=2,
                check=False,
                shell=False,
                **hidden_process_kwargs(),
            )
            for line in completed.stdout.splitlines():
                fields = line.split()
                if len(fields) >= 4 and fields[0:2] == ["0.0.0.0", "0.0.0.0"]:
                    ipaddress.ip_address(fields[2])
                    gateway = fields[2]
                    break
        except (OSError, ValueError, subprocess.SubprocessError):
            pass

    _gateway_cache = (now, gateway)
    return gateway


def collect_network_stats() -> dict[str, Any]:
    try:
        counters = psutil.net_io_counters(pernic=True) or {}
    except (OSError, RuntimeError):
        counters = {}
    try:
        address_map = psutil.net_if_addrs() or {}
    except (OSError, RuntimeError):
        address_map = {}
    try:
        stats_map = psutil.net_if_stats() or {}
    except (OSError, RuntimeError):
        stats_map = {}

    sampled_at = time.monotonic()
    interfaces: list[dict[str, Any]] = []

    with _state_lock:
        for name in sorted(set(counters) | set(address_map) | set(stats_map)):
            counter = counters.get(name)
            stat = stats_map.get(name)
            ipv4, ipv6, mac = _address_details(address_map.get(name, []))
            bytes_sent = int(getattr(counter, "bytes_sent", 0))
            bytes_received = int(getattr(counter, "bytes_recv", 0))
            packets_sent = int(getattr(counter, "packets_sent", 0))
            packets_received = int(getattr(counter, "packets_recv", 0))

            previous = _previous_interfaces.get(name)
            if previous is None:
                upload_bps = 0.0
                download_bps = 0.0
            else:
                elapsed = max(0.001, sampled_at - previous[0])
                upload_bps = max(0.0, (bytes_sent - previous[1]) / elapsed)
                download_bps = max(0.0, (bytes_received - previous[2]) / elapsed)
            _previous_interfaces[name] = (sampled_at, bytes_sent, bytes_received)

            session_start = _session_interfaces.setdefault(
                name,
                (bytes_sent, bytes_received),
            )
            loopback = _is_loopback(name, ipv4, ipv6)
            virtual = any(marker in name.lower() for marker in _virtual_markers)
            is_up = bool(getattr(stat, "isup", False))

            interfaces.append(
                {
                    "name": name,
                    "display_name": name,
                    "is_up": is_up,
                    "is_loopback": loopback,
                    "is_virtual": virtual,
                    "connection_status": "active" if is_up else "inactive",
                    "ipv4": ipv4,
                    "ipv6": ipv6,
                    "mac_address": mac,
                    "speed_mbps": int(getattr(stat, "speed", 0) or 0),
                    "mtu": int(getattr(stat, "mtu", 0) or 0),
                    "bytes_sent": bytes_sent,
                    "bytes_received": bytes_received,
                    "packets_sent": packets_sent,
                    "packets_received": packets_received,
                    "upload_bps": round(upload_bps, 2),
                    "download_bps": round(download_bps, 2),
                    "session_bytes_sent": max(0, bytes_sent - session_start[0]),
                    "session_bytes_received": max(
                        0,
                        bytes_received - session_start[1],
                    ),
                }
            )

    outbound_ip = _outbound_local_ip()
    candidates = [
        interface
        for interface in interfaces
        if interface["is_up"] and not interface["is_loopback"]
    ]
    active = (
        max(
            candidates,
            key=lambda interface: _interface_priority(interface, outbound_ip),
        )
        if candidates
        else None
    )

    return {
        "sampled_at": datetime.now(timezone.utc).isoformat(),
        "connection_status": "online" if active is not None else "offline",
        "active_interface": active["name"] if active else None,
        "local_ip": active["ipv4"] if active else None,
        "gateway": _default_gateway(),
        "upload_bps": active["upload_bps"] if active else 0.0,
        "download_bps": active["download_bps"] if active else 0.0,
        "bytes_sent": active["bytes_sent"] if active else 0,
        "bytes_received": active["bytes_received"] if active else 0,
        "session_bytes_sent": active["session_bytes_sent"] if active else 0,
        "session_bytes_received": active["session_bytes_received"] if active else 0,
        "packets_sent": active["packets_sent"] if active else 0,
        "packets_received": active["packets_received"] if active else 0,
        "interfaces": interfaces,
    }


@router.get("")
def get_network_stats() -> dict[str, Any]:
    return collect_network_stats()


@router.post("/ping")
def post_network_ping(request: PingRequest) -> dict[str, Any]:
    return ping_target(request)
