
import tkinter as tk
from tkinter import ttk
import psutil
import platform
import subprocess
from PIL import Image, ImageTk, ImageOps
import os

from importlib.metadata import version, PackageNotFoundError

try:
    VERSION = version("hardwaremon")
except PackageNotFoundError:
    VERSION = "dev"

#########################
ICON_FILES = {
    "CPU": "cpu.png",
    "RAM": "ram.png",
    "DISK": "disk.png",
    "GPU": "gpu.png",
    "BOARD": "board.png",
    "OS": "os.png"
}

ICON_SIZE = (32, 32)

#########################
# THEMES
#########################
THEMES = {
    "dark": {"bg": "#000000", "fg": "#ffffff", "sidebar": "#181818", "highlight": "#ffffff"},
    "blue": {"bg": "#000000", "fg": "#0080FF", "sidebar": "#000000", "highlight": "#0080FF"},
    "red": {"bg": "#000000", "fg": "#FF0000", "sidebar": "#000000", "highlight": "#FF0000"},
    "green": {"bg": "#000000", "fg": "#00FF00", "sidebar": "#000000", "highlight": "#00FF00"}
}

current_theme = "dark"
theme_names = list(THEMES.keys())

#########################
# ICON LOADER
#########################
def load_icon(name):
    try:
        # __file__ is the path to this script
        path = os.path.join(os.path.dirname(__file__), "icons", name)
        img = Image.open(path).convert("RGBA")
        img = img.resize((32, 32), Image.Resampling.LANCZOS)
        return ImageTk.PhotoImage(img)
    except Exception as e:
        print(f"Error loading icon {name}: {e}")
        return None

#########################
# HARDWARE FUNCTIONS
#########################
def cpu_info():
    return [
        "=== CPU INFORMATION ===", "",
        f"Processor: {platform.processor()}",
        f"Cores: {psutil.cpu_count(logical=False)}",
        f"Threads: {psutil.cpu_count(logical=True)}",
        f"Usage: {psutil.cpu_percent()} %"
    ]

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
        "=== DISK INFORMATION ===", "",
        f"Total: {round(d.total/1e9,2)} GB",
        f"Used: {round(d.used/1e9,2)} GB",
        f"Free: {round(d.free/1e9,2)} GB",
        f"Percent Used: {d.percent} %"
    ]

def gpu_info():
    lines = ["=== GPU INFORMATION ===", ""]
    try:
        nvidia = subprocess.getoutput("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader")
        if nvidia:
            for line in nvidia.strip().split("\n"):
                lines.append(line.strip())
        else:
            out = subprocess.getoutput("lspci | grep -i 'vga'")
            if out:
                lines.extend(out.strip().split("\n"))
            else:
                lines.append("GPU info not available")
    except Exception as e:
        lines.append(f"GPU info error: {e}")
    return lines

def motherboard_info():
    lines = ["=== MOTHERBOARD ===", ""]
    try:
        out = subprocess.getoutput("cat /sys/devices/virtual/dmi/id/board_name")
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

#########################
# SECTIONS
#########################
SECTIONS = {
    "CPU": cpu_info,
    "RAM": ram_info,
    "DISK": disk_info,
    "GPU": gpu_info,
    "BOARD": motherboard_info,
    "OS": os_info
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
        text.delete("1.0", tk.END)
        def step(i):
            if i >= len(lines): return
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