from email.mime import text
from logging import root
import platform
import os
import time
import shutil
import re
import requests
import psutil
import tkinter.messagebox as messagebox
import subprocess
from subprocess import run, PIPE

VERSION = "dev"

MAX_POINTS = 60  # last 60 seconds

cpu_history = []
mem_history = []
disk_history = []


import requests

def check_for_updates():
    repo = "louisboii747/HardwareMon" 
    url = f"https://api.github.com/repos/{repo}/releases/latest"

    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            latest_version = response.json()["tag_name"].lstrip("v")
            if VERSION != "dev" and latest_version != VERSION:
                return f"Update available: v{latest_version}"
        return None  # No update
    except Exception:
        return None  # Fail silently

def update_history():
    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory().percent
    disk = psutil.disk_usage('/').percent

    cpu_history.append(cpu)
    mem_history.append(mem)
    disk_history.append(disk)

    if len(cpu_history) > MAX_POINTS:
        cpu_history.pop(0)
        mem_history.pop(0)


def draw_graph(canvas, data, color, label):
    canvas.delete("all")

    width = int(canvas["width"])
    height = int(canvas["height"])
    padding = 10

    if len(data) < 2:
        return

    max_val = 100  # percent-based graph
    step_x = (width - 2 * padding) / (len(data) - 1)

    points = []
    for i, value in enumerate(data):
        x = padding + i * step_x
        y = height - padding - (value / max_val) * (height - 2 * padding)
        points.extend([x, y])

    canvas.create_line(points, fill=color, width=2, smooth=True)
    canvas.create_text(
        5, 5,
        anchor="nw",
        text=f"{label}: {data[-1]:.1f}%",
        fill=color,
        font=("monospace", 10, "bold")
    )


ALERTS = {
    "cpu": 90,
    "memory": 90,
    "gpu_temp": 80,
    "battery_low": 20
}

def check_alerts():
    alerts = []
    cpu = psutil.cpu_percent(interval=None)
    if cpu > ALERTS["cpu"]:
        alerts.append(f"⚠️ CPU Usage High: {cpu:.1f}%")
    
    mem = psutil.virtual_memory().percent
    if mem > ALERTS["memory"]:
        alerts.append(f"⚠️ Memory Usage High: {mem:.1f}%")
    
    temps = psutil.sensors_temperatures()
    if temps:
        for name, entries in temps.items():
            for entry in entries:
                if "gpu" in entry.label.lower() or "nvidia" in name.lower():
                    if entry.current > ALERTS["gpu_temp"]:
                        alerts.append(f"⚠️ GPU Temp High: {entry.current} °C")
    
    bat = psutil.sensors_battery()
    if bat and not bat.power_plugged and bat.percent < ALERTS["battery_low"]:
        alerts.append(f"⚠️ Battery Low: {bat.percent:.1f}%")
    
    return alerts


def gpu_info():
    lines = ["=== GPU INFORMATION ===", ""]
    try:
        # Try NVIDIA first
        nvidia = subprocess.getoutput("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader")
        if nvidia and "error" not in nvidia.lower() and "not found" not in nvidia.lower():
            for line in nvidia.strip().split("\n"):
                lines.append(line.strip())
            return lines

        # Try AMD via rocm-smi
        amd = subprocess.getoutput("rocm-smi --showproductname 2>/dev/null")
        if amd and "not found" not in amd.lower() and "error" not in amd.lower():
            for line in amd.strip().split("\n"):
                lines.append(line.strip())
            return lines

        # Fall back to lspci
        out = subprocess.getoutput("lspci | grep -Ei 'vga|3d|display'")
        if out:
            lines.extend(out.strip().split("\n"))
        else:
            lines.append("GPU info not available")

    except Exception as e:
        lines.append(f"GPU info error: {e}")
    return lines
    
    # GPU temp (if available)
    temps = psutil.sensors_temperatures()
    if temps:
        for name, entries in temps.items():
            for entry in entries:
                if "gpu" in entry.label.lower() or "nvidia" in name.lower():
                    if entry.current > ALERTS["gpu_temp"]:
                        alerts = []
                        alerts.append(f"⚠️ GPU Temp High: {entry.current} °C")
    
    # Battery
    bat = psutil.sensors_battery()
    if bat and not bat.power_plugged and bat.percent < ALERTS["battery_low"]:
        alerts = []
        alerts.append(f"⚠️ Battery Low: {bat.percent:.1f}%")

    return alerts

def get_cpu_name():
    if platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo") as f:
                for line in f:
                    if "model name" in line:
                        return line.split(":", 1)[1].strip()
        except Exception:
            pass
    return platform.processor()

THEMES = {
    "dark": {
        "bg": "#111111",
        "fg": "#e6e6e6",
        "accent": "#4fc3f7"
    },
    "hacker": {
        "bg": "#000000",
        "fg": "#00ff00",
        "accent": "#00cc00"
    },
    "red": {
        "bg": "#2e0000",
        "fg": "#ff4d4d",
        "accent": "#ff1a1a"
    },
    "black on white": {
        "bg": "#ffffff",
        "fg": "#000000",
        "accent": "#000000"
    },
    "blue": {
        "bg": "#001f3f",
        "fg": "#7FDBFF",
        "accent": "#FFFFFF"
    },
    "purple": {
        "bg": "#2e003e",
        "fg": "#ff66ff",
        "accent": "#ff1aff"
    }
}




def apply_theme(root, text, theme_name):
    theme = THEMES[theme_name]
    root.configure(bg=theme["bg"])
    text.configure(
        bg=theme["bg"],
        fg=theme["fg"],
        insertbackground=theme["fg"]  # caret color
    )


current_theme = "dark"  # default


def read_sys(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return None

def battery_info():
    lines = ["=== Battery Information ==="]
    if not hasattr(psutil, "sensors_battery"):
        return None
    bat = psutil.sensors_battery()
    if bat is None:
        return None
    percent = bat.percent
    plugged = bat.power_plugged
    secsleft = bat.secsleft
    if secsleft == psutil.POWER_TIME_UNLIMITED:
        time_str = "N/A"
    elif secsleft == psutil.POWER_TIME_UNKNOWN:
        time_str = "Unknown"
    else:
        hours, remainder = divmod(secsleft, 3600)
        minutes, _ = divmod(remainder, 60)
        time_str = f"{hours}h {minutes}m"
    return f"{percent}% {'(Charging)' if plugged else '(Discharging)'} - Time left: {time_str}"
    return lines

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')


## START SYSTEM SUMMARY ##

# ---------- Summary Function ----------
def system_summary():
    lines = ["=== SYSTEM SUMMARY ==="]

    cpu_name = get_cpu_name()
    total_ram = round(psutil.virtual_memory().total / (1024**3), 1)
    disk_total = round(psutil.disk_usage('/').total / (1024**3), 1)

    # GPU name (simplified)
    gpu_name = "Unknown"
    if platform.system() == "Linux":
        output = os.popen(
            "lspci | grep -Ei '(VGA|3D)' | grep -Ei '(NVIDIA|AMD)'"
        ).read().strip()
        if output:
            gpu_name = output.split(":")[-1].strip()

    lines.append(f"CPU  : {cpu_name}")
    lines.append(f"GPU  : {gpu_name}")
    lines.append(f"RAM  : {total_ram} GB")
    lines.append(f"Disk : {disk_total} GB\n")

    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory().percent
    disk = psutil.disk_usage('/').percent

    lines.append(f"CPU Usage   : {cpu:.1f}%")
    lines.append(f"Memory Usage: {mem:.1f}%")
    lines.append(f"Disk Usage  : {disk:.1f}%")

    return lines

# ---------- Full Sections ---------- #

SECTIONS = [
    system_summary
]


## END System Summary ##



def system_info():
    lines = ["=== System Information ==="]
    try:
        uptime_seconds = time.time() - psutil.boot_time()
        info = [
            f"OS/Kernel Version: {platform.system()} {platform.release()}",
            f"Architecture: {platform.machine()}",
            f"CPU: {get_cpu_name()}",
            f"CPU Frequency: {psutil.cpu_freq().current:.2f} MHz",
            f"CPU Cores: {psutil.cpu_count(logical=False)}",
            f"Threads: {psutil.cpu_count(logical=True)}",
            f"Memory: {round(psutil.virtual_memory().total / (1024**3), 2)} GB",
            f"Disk: {round(psutil.disk_usage('/').total / (1024**3), 2)} GB",
            f"Uptime: {uptime_seconds / 3600:.2f} hours",
            f"User: {os.getlogin()}",
            f"Display Size: {shutil.get_terminal_size().columns}x{shutil.get_terminal_size().lines}",
            f"Filesystem: {platform.system()}"
           f"Resizable Bar: {'Supported' if os.path.exists('/sys/bus/pci/devices/0000:00:01.0/resizable_bar') else 'Not Supported'}"
        
        ]

        io = psutil.disk_io_counters()
        if io:
            info.append(
                f"Disk Activity: {io.read_bytes / (1024**2):.2f} MB read, "
                f"{io.write_bytes / (1024**2):.2f} MB written"
            )

        bat = battery_info()
        info.append(f"Battery: {bat if bat else 'N/A'}")

        return info

    except Exception as e:
        return [f"System info error: {e}"]
    

## END System Info ##

def swap_memory():
    lines = ["=== Swap Memory ==="]
    swap = psutil.swap_memory()
    lines.append(f"Swap: {round(swap.total / (1024**3), 2)} GB, Used: {round(swap.used / (1024**3), 2)} GB ({swap.percent}%)")
    return lines





def memory_temperature():
    lines = ["=== Memory Temperature ==="]
    temps = psutil.sensors_temperatures()
    if not temps:
        return ["===Memory temperature sensors not available"]

    for name, entries in temps.items():
        for entry in entries:
            if "memory" in entry.label.lower() or "ram" in name.lower():
                if entry.label:
                    lines.append(f"{entry.label}: {entry.current} °C")
                else:
                    lines.append(f"{name}: {entry.current} °C")

    return lines if len(lines) > 1 else ["===No Memory temperature data found==="]




def intel_gpu_info():
    lines = ["=== Intel GPU Information ==="]
    try:
        if platform.system() == "Linux":
            intel_gpu_output = os.popen("lspci | grep -i 'intel' | grep -i 'vga\\|3d\\|2d'").read()
            gpus = intel_gpu_output.strip().split("\n")
            if not gpus or gpus == ['']:
                return ["No Intel GPU information found."]
            for gpu in gpus:
                lines.append(gpu)
        else:
            lines.append("Intel GPU info not implemented for this OS.")
    except Exception as e:
        lines.append(f"Intel GPU info error: {e}")
    return lines


def cpu_mem_bar():
    cpu = psutil.cpu_percent(interval=None)
    lines = ["=== CPU and Memory Usage ==="]
    mem = psutil.virtual_memory().percent
    width = 50
    cpu_bar = "#" * int(cpu / 100 * width)
    mem_bar = "#" * int(mem / 100 * width)
    lines.append(f"CPU: [{cpu_bar:<{width}}] {cpu:.1f}%")
    lines.append(f"MEM: [{mem_bar:<{width}}] {mem:.1f}%")
    return lines


def network_info():
    net = psutil.net_io_counters(pernic=True)
    lines = ["=== Network Interfaces ==="]
    for iface, data in net.items():
        lines.append(f"{iface:10}: Sent={data.bytes_sent / (1024**2):6.2f} MB | Recv={data.bytes_recv / (1024**2):6.2f} MB")
    return lines



def top_processes(n=5):
    procs = [(p.info["name"], p.info["cpu_percent"], p.info["memory_percent"])
             for p in psutil.process_iter(["name", "cpu_percent", "memory_percent"])]
    procs.sort(key=lambda x: (x[1], x[2]), reverse=True)
    lines = [f"=== Top {n} Processes ==="]
    for name, cpu, mem in procs[:n]:
        lines.append(f"{name[:25]:25} | CPU: {cpu:5.1f}% | MEM: {mem:5.1f}%")
    return lines




def motherboard_info():
    lines = ["=== Motherboard Information ==="]

    if platform.system() == "Linux":
        base_path = "/sys/devices/virtual/dmi/id/"
        info = {
            "Manufacturer": read_sys(base_path + "board_vendor"),
            "Product Name": read_sys(base_path + "board_name"),
            "Version": read_sys(base_path + "board_version"),
            "Serial Number": read_sys(base_path + "board_serial"),
        }

        for key, value in info.items():
            lines.append(f"{key}: {value if value else 'N/A'}")

    return lines
    



def fan_info():
    lines = ["=== Fan Sensors ==="]
    hwmon_base = "/sys/class/hwmon"

    if not os.path.exists(hwmon_base):
        return ["Fan sensors not available"]

    for hw in os.listdir(hwmon_base):
        hw_path = os.path.join(hwmon_base, hw)
        name = read_sys(os.path.join(hw_path, "name")) or hw
        
        for file in os.listdir(hw_path):
            if file.startswith("fan") and file.endswith("_input"):
                rpm = read_sys(os.path.join(hw_path, file))
                if rpm and rpm.isdigit():
                    lines.append(f"{name} {file}: {rpm} RPM")

    return lines if len(lines) > 1 else ["==No fans detected==="]




def partition_info():
    lines = ["=== Partition Information ==="]
    for part in psutil.disk_partitions(all=False):
        lines.append(f"{part.device} mounted on {part.mountpoint} - Type: {part.fstype}")
    return lines


def drive_info():
    lines = ["=== Drive Information ==="]
    for part in psutil.disk_partitions(all=False):
        try:
            usage = psutil.disk_usage(part.mountpoint)
        except (PermissionError, FileNotFoundError):
            continue

        lines.append(
            f"{part.mountpoint:15} "
            f"{usage.used // (1024**3):4} / "
            f"{usage.total // (1024**3):4} GB "
            f"({usage.percent:5.1f}%)"
        )

    return lines


def gpu_temperature():
    lines = ["=== GPU Temperature ==="]
    found = False

    # NVIDIA
    nvidia = subprocess.getoutput("nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader 2>/dev/null")
    if nvidia and "not found" not in nvidia.lower() and "error" not in nvidia.lower() and "failed" not in nvidia.lower():
        for line in nvidia.strip().split("\n"):
            parts = line.split(",")
            if len(parts) == 2:
                name, temp = parts[0].strip(), parts[1].strip()
                lines.append(f"{name}: {temp} °C")
                found = True

    # AMD via rocm-smi
    amd = subprocess.getoutput("rocm-smi --showtemp 2>/dev/null")
    if amd and "not found" not in amd.lower() and "error" not in amd.lower():
        for line in amd.strip().split("\n"):
            if "temperature" in line.lower() or "°c" in line.lower() or "temp" in line.lower():
                lines.append(line.strip())
                found = True

    # AMD fallback via hwmon (works without rocm-smi)
    if not found:
        hwmon_base = "/sys/class/hwmon"
        if os.path.exists(hwmon_base):
            for hw in os.listdir(hwmon_base):
                hw_path = os.path.join(hwmon_base, hw)
                name = read_sys(os.path.join(hw_path, "name")) or ""
                if "amdgpu" in name.lower():
                    for f in os.listdir(hw_path):
                        if f.startswith("temp") and f.endswith("_input"):
                            raw = read_sys(os.path.join(hw_path, f))
                            label_file = f.replace("_input", "_label")
                            label = read_sys(os.path.join(hw_path, label_file)) or f
                            if raw and raw.isdigit():
                                lines.append(f"AMD ({label}): {int(raw) // 1000} °C")
                                found = True

    return lines if found else ["=== No GPU temperature data found ==="]


def get_package_manager():
    for pm, cmd in [("apt", "sudo apt install i2c-tools"),
                    ("dnf", "sudo dnf install i2c-tools"),
                    ("pacman", "sudo pacman -S i2c-tools"),
                    ("zypper", "sudo zypper install i2c-tools")]:
        if subprocess.getoutput(f"which {pm} 2>/dev/null").strip():
            return cmd
    return "install i2c-tools via your package manager"

def memory_temperature():
    lines = ["=== Memory Temperature ==="]
    temps = psutil.sensors_temperatures()

    if not temps:
        return ["No temperature sensors available"]

    for name, entries in temps.items():
        for entry in entries:
            label = (entry.label or "").lower()
            name_l = name.lower()

            if any(keyword in (label + name_l) for keyword in ["dimm", "spd", "memory", "ram"]):
                display = entry.label if entry.label else name
                lines.append(f"{display}: {entry.current} °C")

    return lines if len(lines) > 1 else ["=== No memory temperature data exposed by hardware/kernel ==="]


def cpu_temperature():
    lines = ["=== CPU Core Temperatures ==="]
    temps = psutil.sensors_temperatures()

    if not temps:
        return ["CPU temperature sensors not available"]

    for name, entries in temps.items():
        if "core" not in name.lower():
            continue

        for entry in entries:
            if entry.label and "core" in entry.label.lower():
                lines.append(f"{entry.label}: {entry.current} °C")

    if len(lines) == 1:
        return ["CPU core temperature sensors not found"]

    return lines


def keyboard_info():
    lines = ["=== Keyboard Information ==="]
    try:
        if platform.system() == "Linux":
            lsusb_output = os.popen("lsusb | grep -i 'keyboard'").read()
            keyboards = lsusb_output.strip().split("\n")
            if not keyboards or keyboards == ['']:
                return ["===No keyboard information found.==="]
            for kb in keyboards:
                lines.append(kb)
        else:
            lines.append("===Keyboard info not implemented for this OS.===")
    except Exception as e:
        lines.append(f"Keyboard info error: {e}")
    return lines


def mouse_info():
    lines = ["=== Mouse Information ==="]
    try:
        if platform.system() == "Linux":
            lsusb_output = os.popen("lsusb | grep -i 'mouse'").read()
            mice = lsusb_output.strip().split("\n")
            if not mice or mice == ['']:
                return ["===No mouse information found.==="]
            for mouse in mice:
                lines.append(mouse)
        else:
            lines.append("===Mouse info not implemented for this OS.===")
    except Exception as e:
        lines.append(f"Mouse info error: {e}")
    return lines


def os_info():
    lines = ["=== Operating System Information ==="]
    try:
        if platform.system() == "Linux":
            distro = ""
            try:
                with open("/etc/os-release") as f:
                    for line in f:
                        if line.startswith("PRETTY_NAME="):
                            distro = line.split("=")[1].strip().strip('"')
                            break
            except Exception:
                distro = "Unknown Linux Distro"
            lines.append(f"Distribution: {distro}")
        elif platform.system() == "Windows":
            lines.append(f"Windows Version: {platform.version()}")
        elif platform.system() == "Darwin":
            mac_ver = platform.mac_ver()[0]
            lines.append(f"macOS Version: {mac_ver}")
        else:
            lines.append("OS information not implemented for this OS.")
    except Exception as e:
        lines.append(f"OS info error: {e}")
    return lines


def wifi_info():
    lines = ["=== Wi-Fi Information ==="]
    try:
        if platform.system() == "Linux":
            iwconfig_output = os.popen("iwconfig 2>/dev/null | grep 'ESSID'").read()
            wifis = iwconfig_output.strip().split("\n")
            if not wifis or wifis == ['']:
                return ["===No Wi-Fi information found.==="]
            for wifi in wifis:
                lines.append(wifi)
        else:
            lines.append("===Wi-Fi info not implemented for this OS.===")
    except Exception as e:
        lines.append(f"Wi-Fi info error: {e}")
    return lines



current_theme = "dark"

# List of all section functions
SECTIONS = [
    system_info,
    swap_memory,
    network_info,
    top_processes,
    cpu_mem_bar,
    drive_info,
    fan_info,
    motherboard_info,
    cpu_temperature,
    gpu_info,
    gpu_temperature,
    memory_temperature,
    os_info,
    keyboard_info,
    mouse_info,
    wifi_info,
    partition_info,
    intel_gpu_info,

]

def apply_theme(root, text, theme_name):
    theme = THEMES[theme_name]
    root.configure(bg=theme["bg"])
    text.configure(bg=theme["bg"], fg=theme["fg"], insertbackground=theme["fg"])


# ---------- Summary ---------- #
def system_summary():
    lines = ["=== SYSTEM SUMMARY ==="]

    cpu_name = get_cpu_name()
    total_ram = round(psutil.virtual_memory().total / (1024**3), 1)
    disk_total = round(psutil.disk_usage('/').total / (1024**3), 1)

    # GPU name (simplified)
    gpu_name = "Unknown"
    if platform.system() == "Linux":
        output = os.popen(
            "lspci | grep -Ei '(VGA|3D)' | grep -Ei '(NVIDIA|AMD)'"
        ).read().strip()
        if output:
            gpu_name = output.split(":")[-1].strip()

    lines.append(f"CPU  : {cpu_name}")
    lines.append(f"GPU  : {gpu_name}")
    lines.append(f"RAM  : {total_ram} GB")
    lines.append(f"Disk : {disk_total} GB\n")

    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory().percent
    disk = psutil.disk_usage('/').percent

    lines.append(f"CPU Usage   : {cpu:.1f}%")
    lines.append(f"Memory Usage: {mem:.1f}%")
    lines.append(f"Disk Usage  : {disk:.1f}%")

    return lines

SECTIONS = [ 
    system_info,
    swap_memory,
    network_info,
    top_processes,
    cpu_mem_bar,
    drive_info,
    fan_info,
    motherboard_info,
    cpu_temperature,
    gpu_info,
    gpu_temperature,
    memory_temperature,
    os_info,
    keyboard_info,
    mouse_info,
    wifi_info,
    partition_info,
    intel_gpu_info
]

import time

# Global cache for update messages
_last_update_check = 0
_update_msg_cache = None
UPDATE_CHECK_INTERVAL = 600  # seconds (10 minutes)

def check_for_updates_cached():
    global _last_update_check, _update_msg_cache
    now = time.time()

    if now - _last_update_check > UPDATE_CHECK_INTERVAL:
        _last_update_check = now
        _update_msg_cache = check_for_updates()  # your existing function

    return _update_msg_cache


# ---------- GUI App ---------- #



import tkinter as tk
def gui_app():
    root = tk.Tk()
    root.title("HardwareMon")
    root.geometry("800x600")

    summary_mode = tk.BooleanVar(value=True)

    # ---- Create widgets ---- #
    version_label = tk.Label(root, text=f"HardwareMon {VERSION}",
                             font=("monospace", 12, "bold"))
    version_label.pack(anchor="ne", padx=10, pady=5)

    text = tk.Text(root, font=("monospace", 11))
    text.pack(fill="both", expand=True, padx=5, pady=5)

    main_frame = tk.Frame(root)
    main_frame.pack(pady=5, fill="x")

    toggle_btn = tk.Button(main_frame, text="Show Full Stats")
    toggle_btn.pack(pady=2)

    cpu_canvas = tk.Canvas(main_frame, width=780, height=100)
    cpu_canvas.pack(pady=2)
    mem_canvas = tk.Canvas(main_frame, width=780, height=100)
    mem_canvas.pack(pady=2)
    disk_canvas = tk.Canvas(main_frame, width=780, height=100)
    disk_canvas.pack(pady=2)

    # ----  define functions ---- #
    def apply_theme_gui(theme_name):
        theme = THEMES[theme_name]
        root.configure(bg=theme["bg"])
        text.configure(bg=theme["bg"], fg=theme["fg"], insertbackground=theme["fg"])
        version_label.configure(bg=theme["bg"], fg=theme["fg"])
        toggle_btn.configure(bg=theme["bg"], fg=theme["fg"])
        main_frame.configure(bg=theme["bg"])
        cpu_canvas.configure(bg=theme["bg"])
        mem_canvas.configure(bg=theme["bg"])
        disk_canvas.configure(bg=theme["bg"])

    def refresh_text():
        scroll = text.yview()
        text.delete("1.0", tk.END)
        alerts = check_alerts()
        update_msg = check_for_updates_cached()

        if alerts:
            version_label.config(text=" | ".join(alerts))
        elif update_msg:
            version_label.config(text=f"HardwareMon {VERSION} → {update_msg}")
        else:
            version_label.config(text=f"HardwareMon {VERSION}")

        active_sections = [system_summary] if summary_mode.get() else SECTIONS
        for section in active_sections:
            lines = section()
            for line in lines:
                text.insert(tk.END, line + "\n")
            text.insert(tk.END, "\n")

        text.yview_moveto(scroll[0])

        update_history()
        draw_graph(cpu_canvas, cpu_history, THEMES[current_theme]["accent"], "CPU")
        draw_graph(mem_canvas, mem_history, THEMES[current_theme]["accent"], "Memory")
        draw_graph(disk_canvas, disk_history, THEMES[current_theme]["accent"], "Disk")

    def toggle_view():
        summary_mode.set(not summary_mode.get())
        toggle_btn.config(text="Show Full Stats" if summary_mode.get() else "Show Summary")
        refresh_text()

    toggle_btn.config(command=toggle_view)

    def switch_theme(event=None):
        global current_theme
        theme_names = list(THEMES.keys())
        next_index = (theme_names.index(current_theme) + 1) % len(theme_names)
        current_theme = theme_names[next_index]
        apply_theme_gui(current_theme)
        refresh_text()

    root.bind("<F2>", lambda e: toggle_view())
    root.bind("<F3>", switch_theme)

    apply_theme_gui(current_theme)
    refresh_text()

    def update_loop():
        refresh_text()
        root.after(1000, update_loop)

    update_loop()
    root.mainloop()





def main():
    check_for_updates()
    gui_app()
if __name__ == "__main__":
    main()

## -- END GUI APP -- ##


## Made with <3 by Louis ##
