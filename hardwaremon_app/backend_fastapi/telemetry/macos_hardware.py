"""Defensive, cached macOS hardware identification helpers."""

from functools import lru_cache
import platform
import re
import subprocess

from process_utils import hidden_process_kwargs


_GENERIC_ARM_NAMES = {"arm", "arm64", "aarch64", "unknown", "unknown cpu"}
_APPLE_CHIP_PATTERN = re.compile(
    r"\bApple\s+M\d+(?:\s+(?:Pro|Max|Ultra))?\b",
    re.IGNORECASE,
)


def _run_command(arguments, timeout=3):
    try:
        result = subprocess.run(
            arguments,
            capture_output=True,
            check=True,
            text=True,
            timeout=timeout,
            **hidden_process_kwargs(),
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout.strip()


def _sysctl_value(name):
    return _run_command(["/usr/sbin/sysctl", "-n", name], timeout=2)


def parse_system_profiler_hardware(output):
    """Parse stable labels while ignoring ordering and unknown extra fields."""
    values = {}
    labels = {
        "chip": "chip",
        "processor name": "processor_name",
        "model name": "model_name",
        "model identifier": "model_identifier",
    }
    for line in (output or "").splitlines():
        if ":" not in line:
            continue
        label, value = line.split(":", 1)
        key = labels.get(label.strip().lower())
        cleaned = value.strip()
        if key and cleaned:
            values[key] = cleaned
    return values


def normalize_apple_chip(value):
    match = _APPLE_CHIP_PATTERN.search(value or "")
    if not match:
        return ""
    words = match.group(0).split()
    return " ".join(
        word.capitalize() if word.lower() in {"pro", "max", "ultra"} else word
        for word in words
    )


def choose_macos_cpu_name(machine, brand_string="", profiler=None, processor=""):
    profiler = profiler or {}
    is_apple_silicon = machine.strip().lower() in {"arm64", "aarch64", "arm"}
    candidates = (
        brand_string,
        profiler.get("chip", ""),
        profiler.get("processor_name", ""),
        processor,
    )

    if is_apple_silicon:
        for candidate in candidates:
            chip = normalize_apple_chip(candidate)
            if chip:
                return chip
        for candidate in candidates:
            cleaned = candidate.strip()
            if cleaned and cleaned.lower() not in _GENERIC_ARM_NAMES:
                return cleaned
        return "Apple Silicon"

    for candidate in candidates:
        cleaned = candidate.strip()
        if cleaned and cleaned.lower() not in _GENERIC_ARM_NAMES:
            return cleaned
    return "Intel Mac" if machine.strip().lower() in {"x86_64", "amd64", "i386"} else "Unknown CPU"


@lru_cache(maxsize=1)
def read_macos_hardware_info():
    """Read static Mac identity once; system_profiler must never run per poll."""
    machine = platform.machine().strip() or "Unknown"
    processor = platform.processor().strip()
    brand_string = _sysctl_value("machdep.cpu.brand_string")
    model_identifier = _sysctl_value("hw.model")

    profiler = {}
    needs_profiler = not normalize_apple_chip(brand_string)
    if needs_profiler:
        profiler = parse_system_profiler_hardware(
            _run_command(
                ["/usr/sbin/system_profiler", "SPHardwareDataType"],
                timeout=8,
            )
        )

    model_identifier = model_identifier or profiler.get("model_identifier", "")
    model_name = profiler.get("model_name", "")
    cpu_name = choose_macos_cpu_name(
        machine,
        brand_string=brand_string,
        profiler=profiler,
        processor=processor,
    )
    chip_name = normalize_apple_chip(cpu_name)

    return {
        "cpu_name": cpu_name,
        "chip_name": chip_name or ("Apple Silicon" if machine.lower() in {"arm64", "aarch64", "arm"} else ""),
        "architecture": machine,
        "model_identifier": model_identifier or "Unknown Mac model",
        "model_name": model_name or model_identifier or "Mac",
    }

