# HardwareMon

HardwareMon is a lightweight system monitoring tool designed to provide a detailed overview of your computer's hardware and performance metrics. It can display CPU, memory, disk, GPU, battery, network, and peripheral information in real time. The project includes a Python GUI version for Linux, a modern Windows GUI application, and a PowerShell version for Windows.

## Features

HardwareMon gathers and presents information such as CPU usage, memory usage, disk activity, top running processes, GPU specifications and temperatures, battery status, and peripheral details. On Linux, the Python version uses the psutil library and native system commands to extract detailed system information. On Windows, both the new Python GUI and the PowerShell version leverage CIM/WMI queries to report similar statistics.

The Linux version includes a GUI mode built with Tkinter, offering a modern and configurable interface with light, dark, and hacker-style themes. To cycle themes, press F2. Graphs for CPU, memory, and disk usage are updated in real time, providing a quick visual snapshot of system performance.

The Windows GUI version is built with CustomTkinter and features a Windows 11 Fluent Design-inspired interface with animated arc gauges, live sparkline graphs, per-core CPU bars, a real-time process table, and a full system information page.

---

## Windows (Python GUI — Recommended)

The new Windows GUI is a modern, standalone application built with Python and CustomTkinter. It includes six pages: Overview, CPU, Memory, Disk, Network, and System.

### Running from source

Ensure Python 3 is installed, then install the dependencies:

```
pip install customtkinter psutil gputil
```

Run the app:

```
python hardwaremon_win.py
```

### Building the .exe

To produce a standalone `HardwareMon.exe` that requires no Python installation:

```
pip install pyinstaller
build.bat
```

The finished executable will appear at `Windows\dist\HardwareMon.exe`.

### Optional GPU support

Install `GPUtil` for GPU information on NVIDIA cards:

```
pip install gputil
```

### Notes

- Run as Administrator for complete process visibility.
- The `.exe` is fully self-contained — no Python required on the target machine.
- Tested on Windows 10 and Windows 11.

---

## Windows (PowerShell version)

Open PowerShell and run the script directly:

```
.\hardware-info.ps1
```

The PowerShell version leverages CIM/WMI queries and is provided for convenience. It is not maintained as actively as the Python GUI version and may lack the latest features.

---

## Installation (Linux version)

### Using Git

Ensure Python 3 and the psutil library are installed, then clone the repository and run:

```
python3 hardware_mon.py
```

### Using Pip (Easier, Quicker)

Ubuntu/Debian:

```
sudo apt update
sudo apt install python3-pip python3-tk pipx
pip3 --version
```

RHEL/Fedora:

```
sudo dnf install python3-pip pipx python3-tk
pip3 --version
```

Arch Linux:

```
sudo pacman -S python-pip pipx python3-tk
pip --version
```

Then install HardwareMon:

```
pip install hardwaremon
```

### Fixing the "Externally Managed Environment" Error

On Ubuntu and Debian-based systems you may see `error: externally-managed-environment`. The recommended fix is pipx:

```
sudo apt install pipx
pipx ensurepath
source ~/.bashrc
pipx install hardwaremon
```

Run with either:

```
hardwaremon
hardwaremon_cli
```

**Option 2 — Virtual environment:**

```
python3 -m venv hardwaremon-env
source hardwaremon-env/bin/activate
pip install hardwaremon
```

**Option 3 — Force install (not recommended):**

```
pip install hardwaremon --break-system-packages
```

---

## GUI vs CLI Versions (Linux)

HardwareMon on Linux comes in two flavours. The GUI version separates hardware data into separate pages with clickable icons, while the CLI version displays everything in the terminal.

```
hardwaremon      # GUI version
hardwaremon_cli  # CLI version
```

The GUI version receives the majority of active development.

---

## Q&A

**What platforms is HardwareMon available for?**
Windows and Linux. Linux versions receive more frequent updates. Windows now has a fully featured Python GUI in addition to the PowerShell version.

**What is the difference between hardwaremon and hardwaremon_cli on Linux?**
`hardwaremon` is the GUI version with separate pages and clickable icons. `hardwaremon_cli` is the original terminal-based version.

**Which version should I use?**
On Linux, use `hardwaremon` for the best experience. On Windows, use the Python GUI (`hardwaremon_win.py` or the compiled `.exe`) for a modern, feature-rich interface.

**What do the YAML workflows do?**
One workflow lints the scripts for errors, and the other packages the GUI and CLI versions into a pip package for Linux. Both workflows only operate on the Linux versions.

**Can I contribute?**
Absolutely! Feel free to fork the repo and submit pull requests or report issues on the issue tracker.

---

## Notes

The Windows PowerShell version relies on CIM/WMI queries and may have limitations on certain hardware or older operating systems. The Linux Python version provides more extensive monitoring, including GPU lane and VRAM information for NVIDIA and AMD cards.

The `.sh` script is more basic than the `.py` script on Linux, as it cannot use Tkinter for graph drawing.

The GitHub Actions workflows only run on the Linux versions.

---

Made with ❤️ by Louis
