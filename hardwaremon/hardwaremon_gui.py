# GUI CODE FOR HARDWAREMON
import tkinter as tk
from tkinter import ttk
import psutil
import platform
import subprocess
from PIL import Image, ImageTk, ImageOps
import os

VERSION = "dev"

######################
ICON_FILES = {
    "CPU": "cpu.png",
    "RAM": "ram.png",
    "DISK": "disk.png",
    "GPU": "gpu.png",
    "BOARD": "board.png",
    "OS": "os.png",
    "Wi-Fi" : "network.png"
}

ICON_SIZE = (32, 32)

######################
# THEMES
######################
THEMES = {
    "dark": {"bg": "#000000", "fg": "#ffffff", "sidebar": "#181818", "highlight": "#ffffff"},
    "blue": {"bg": "#000000", "fg": "#0080FF", "sidebar": "#000000", "highlight": "#0080FF"},
    "red": {"bg": "#000000", "fg": "#FF0000", "sidebar": "#000000", "highlight": "#FF0000"},
    "green": {"bg": "#000000", "fg": "#00FF00", "sidebar": "#000000", "highlight": "#00FF00"}
}

current_theme = "dark"
theme_names = list(THEMES.keys())

#########################
# ICON LOADER #
#########################
def load_icon(name):
    try:
        base_dir = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(base_dir, name)

        if not os.path.exists(icon_path):
            print(f"Missing icon: {icon_path}")
            return None

        img = Image.open(icon_path).convert("RGBA")
        img = img.resize(ICON_SIZE, Image.Resampling.LANCZOS)
        return ImageTk.PhotoImage(img)

    except Exception as e:
        print(f"Error loading icon {name}: {e}")
        return None

########################
# HARDWARE FUNCTIONS #
########################
def cpu_info():
    cpu_name = "Unknown"
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    cpu_name = line.split(":")[1].strip()
                    break
    except FileNotFoundError:
        cpu_name = platform.processor()  # fallback for non-Linux

    return [
        "=== CPU INFORMATION ===", "",
        f"Processor: {cpu_name}",
        f"Cores: {psutil.cpu_count(logical=False)}",
        f"Threads: {psutil.cpu_count(logical=True)}",
        f"Usage: {psutil.cpu_percent()} %"
    ]


def cpu_temperature():
    temps = psutil.sensors_temperatures()
    if not temps:
        return ["CPU Temperature: Not available"]

    lines = ["=== CPU TEMPERATURE ===", ""]
    for name, entries in temps.items():
        for entry in entries:
            if "cpu" in entry.label.lower() or "package" in entry.label.lower():
                lines.append(f"{entry.label}: {entry.current} °C")
    return lines

def wifi_info():
    lines = ["=== WIFI INFORMATION ===", ""]
    try:
        out = subprocess.getoutput("ip a | grep 'state UP' -B2 | grep 'w' | awk '{print $2}' | sed 's/://g'")
        if out:
            iface = out.strip()
            lines.append(f"Interface: {iface}")
            data = psutil.net_io_counters(pernic=True).get(iface)
            if data:
                lines.append(f"Sent: {data.bytes_sent / (1024**2):.2f} MB")
                lines.append(f"Received: {data.bytes_recv / (1024**2):.2f} MB")
            else:
                lines.append("No data available for this interface")
        else:
            lines.append("No active Wi-Fi interface found")
    except Exception as e:
        lines.append("Error retrieving Wi-Fi information")
    return lines



def ssid_info():
    lines = ["=== WIFI SSID ===", ""]
    try:
        out = subprocess.getoutput("iwctl station wlan0 get-networks | grep '*' | awk '{print $2}'")
        if out:
            ssid = out.strip()
            lines.append(f"Connected SSID: {ssid}")
        else:
            lines.append("Not connected to any Wi-Fi network")
    except Exception as e:
        lines.append("Error retrieving SSID information, ensure iwctl is installed and you have permissions")
    return lines


def ram_info():
    mem = psutil.virtual_memory()
    return [
        "=== RAM INFORMATION ===", "",
        f"Total: {round(mem.total/1e9,2)} GB",
        f"Used: {round(mem.used/1e9,2)} GB",
        f"Available: {round(mem.available/1e9,2)} GB",
        f"Percent Used: {mem.percent} %"
    ]

def disk_info():
    d = psutil.disk_usage("/")
    return [
        "=== DISK INFORMATION (ROOT PARTITION) ===", "",
        f"Total: {round(d.total/1e9,2)} GB",
        f"Used: {round(d.used/1e9,2)} GB",
        f"Free: {round(d.free/1e9,2)} GB",
        f"Percent Used: {d.percent} %"
    ]

def partitions_info():
    SKIP_FS = {"tmpfs", "devtmpfs", "squashfs"}


    lines = ["=== ALL PARTITIONS ===", ""]
    for part in psutil.disk_partitions():
        if part.fstype not in SKIP_FS:
            lines.append(f"{part.device} - {part.mountpoint} ({part.fstype})")
    return lines



def _try_nvidia(query):
    """Returns output string or None if nvidia-smi is unavailable or failed."""
    try:
        result = subprocess.run(
            ["nvidia-smi", f"--query-gpu={query}", "--format=csv,noheader"],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None

def _try_amd(query_type):
    """Returns output string or None if rocm-smi is unavailable or failed."""
    try:
        flag = {"name": "--showproductname", "vram": "--showmeminfo", "temp": "--showtemp"}[query_type]
        result = subprocess.run(["rocm-smi", flag], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None

def gpu_info():
    lines = ["=== GPU INFORMATION ===", ""]

    nvidia = _try_nvidia("name,memory.total")
    if nvidia:
        lines.append("Vendor: NVIDIA")
        for line in nvidia.split("\n"):
            lines.append(line.strip())
        return lines

    amd = _try_amd("name")
    if amd:
        lines.append("Vendor: AMD")
        for line in amd.split("\n"):
            lines.append(line.strip())
        return lines

    # Fall back to lspci for display name only
    lspci = subprocess.getoutput("lspci | grep -i 'vga\\|3d\\|display'")
    if lspci and "command not found" not in lspci:
        lines.append("No NVIDIA or AMD GPU detected via driver tools.")
        lines.append("Display adapter(s) found via lspci:")
        for line in lspci.strip().split("\n"):
            lines.append(f"  {line.strip()}")
    else:
        lines.append("No NVIDIA or AMD GPU found.")
        lines.append("No display adapter detected via lspci either.")

    return lines

def vram_info():
    lines = ["=== VRAM INFORMATION ===", ""]

    nvidia = _try_nvidia("memory.total,memory.used,memory.free")
    if nvidia:
        labels = ["Total", "Used", "Free"]
        for label, val in zip(labels, nvidia.split(",")):
            lines.append(f"{label}: {val.strip()}")
        return lines

    amd = _try_amd("vram")
    if amd:
        for line in amd.split("\n"):
            lines.append(line.strip())
        return lines

    lines.append("No NVIDIA or AMD GPU found — VRAM info unavailable.")
    return lines

def gpu_temperature_info():
    lines = ["=== GPU TEMPERATURE ===", ""]

    nvidia = _try_nvidia("temperature.gpu")
    if nvidia:
        for line in nvidia.split("\n"):
            lines.append(f"{line.strip()} °C")
        return lines

    amd = _try_amd("temp")
    if amd:
        for line in amd.split("\n"):
            lines.append(line.strip())
        return lines

    lines.append("No NVIDIA or AMD GPU found — temperature unavailable.")
    return lines



def motherboard_info():
    lines = ["=== MOTHERBOARD ===", ""]
    try:
        out = subprocess.getoutput("cat /sys/devices/virtual/dmi/id/board_name")
        lines.append(out.strip() if out else "Unknown")
    except:
        lines.append("Unknown")
    return lines

def secure_boot():
    lines = ["=== SECURE BOOT STATE ===", ""]
    try:
        out = subprocess.getoutput("mokutil --sb-state")
        lines.append(out.strip() if out else "Unknown")
    except:
        lines.append("Unknown")
    return lines

def os_info():
    return [
        "=== OPERATING SYSTEM ===", "",
        f"System: {platform.system()}",
        f"Release: {platform.release()}",
        f"Version: {platform.version()}"
    ]

def current_user():
    return [
        "=== CURRENT USER ===", "",
        f"User: {os.getlogin()}"
    ]

#########################
# SECTIONS
#########################
SECTIONS = {
    "CPU": lambda: cpu_info() + [""] + cpu_temperature(),
    "RAM": ram_info,
    "DISK": lambda: disk_info() + [""] + partitions_info(),
    "GPU": lambda: gpu_info() + [""] + vram_info() + [""] + gpu_temperature_info(),
    "BOARD": lambda: motherboard_info() + [""] + secure_boot(),
    "OS": lambda: os_info() + [""] + current_user(),
    "Wi-Fi" : lambda: wifi_info() + [""] + ssid_info()
}

#########################
# GUI
#########################
def gui():
    root = tk.Tk()
    root.title(f"HardwareMon {VERSION}")
    root.geometry("900x600")

    # Layout
    sidebar = tk.Frame(root, width=80)
    sidebar.pack(side="left", fill="y")
    content = tk.Frame(root)
    content.pack(side="right", expand=True, fill="both")

    text = tk.Text(content, font=("Consolas", 12))
    text.pack(fill="both", expand=True, padx=10, pady=10)
    canvas = tk.Canvas(content, height=150)
    canvas.pack(fill="both", expand=True)

    cpu_hist = [0]*60

    # Animated text
    def animate_text(lines):
        text.configure(state="normal")
        text.delete("1.0", tk.END)

        def step(i):
            if i >= len(lines): 
                text.configure(state="disabled")
                return
            text.configure(state="normal")
            text.insert(tk.END, lines[i] + "\n")
            root.after(20, lambda: step(i+1))

        step(0)

    # CPU Graph
    def draw_graph():
        cpu = psutil.cpu_percent()
        cpu_hist.append(cpu)
        cpu_hist.pop(0)
        canvas.delete("all")

        w = canvas.winfo_width()
        h = canvas.winfo_height()
        step = w/len(cpu_hist)

        # horizontal grid & labels
        for i in range(0, 101, 20):
            y = h - (i/100)*h
            canvas.create_line(0, y, w, y, fill="#444444", dash=(2,4))
            canvas.create_text(30, y-10, text=f"{i}%", fill=THEMES[current_theme]["fg"], anchor="w", font=("Consolas", 10, "bold"))

        # CPU usage line
        x = 0
        lasty = h
        for v in cpu_hist:
            y = h - (v/100)*h
            canvas.create_line(x, lasty, x+step, y, width=2, fill=THEMES[current_theme]["highlight"])
            lasty = y
            x += step

        canvas.create_text(w/2, 10, text="CPU Usage (%)", fill=THEMES[current_theme]["fg"], font=("Consolas", 12, "bold"))

        root.after(500, draw_graph)

    # Section switching
    active_section = "CPU"

    def switch_section(name):
        nonlocal active_section
        active_section = name
        animate_text(SECTIONS[name]())

    # Icons and buttons
    icons = {name: load_icon(path) for name, path in ICON_FILES.items()}
    buttons = {}
    for name in SECTIONS:
        b = tk.Button(sidebar, image=icons[name], command=lambda x=name: switch_section(x))
        b.pack(pady=10)
        buttons[name] = b

    # Theme application
    def apply_theme(theme_name):
        theme = THEMES[theme_name]
        root.configure(bg=theme["bg"])
        sidebar.configure(bg=theme["sidebar"])
        content.configure(bg=theme["bg"])
        text.configure(bg=theme["bg"], fg=theme["fg"], insertbackground=theme["fg"])
        canvas.configure(bg=theme["bg"])

        # recolor icons
        for name, b in buttons.items():
            new_icon = load_icon(ICON_FILES[name])
            b.configure(image=new_icon)
            icons[name] = new_icon

    def toggle_theme(event=None):
        global current_theme
        idx = theme_names.index(current_theme)
        current_theme = theme_names[(idx+1)%len(theme_names)]
        apply_theme(current_theme)

    root.bind("<F2>", toggle_theme)

    # Init
    animate_text(cpu_info())
    draw_graph()
    apply_theme(current_theme)

    root.mainloop()

if __name__ == "__main__":
    gui()

## MADE WITH <3 BY LOUIS