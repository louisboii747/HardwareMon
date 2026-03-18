# HardwareMon #


HardwareMon is a lightweight system monitoring tool designed to provide a detailed overview of your computer’s hardware and performance metrics. It can display CPU, memory, disk, GPU, battery, network, and peripheral information in real time. The project includes two main implementations: a Python version for Linux systems and a PowerShell version for Windows.

## Features ##

HardwareMon gathers and presents information such as CPU usage, memory usage, disk activity, top running processes, GPU specifications and temperatures, battery status, and peripheral details. On Linux, the Python version uses the psutil library and native system commands to extract detailed system information. On Windows, the PowerShell version leverages CIM/WMI queries to report similar statistics.

The Linux version also includes a GUI mode built with Tkinter, offering a modern and configurable interface with light, dark, and hacker-style themes. To cycle themes, press F2. Graphs for CPU, memory, and disk usage are updated in real time, providing a quick visual snapshot of system performance.

## Installation (Linux version) ##


## Using Git ##


Ensure Python 3 and the psutil library are installed.

Clone the repository or download the Python script.

Run the script from a terminal:

```
python3 hardware_mon.py
```

## Using Pip (Easier, Quicker) ##

Recently, I have now made the Linux Python Script a pip package. This makes it even easier to install, with the command being:

First, install Pip.

Ubuntu/Debian
```
sudo apt update
sudo apt install python3-pip 
sudo apt install python3-tk
sudo apt install pipx
pip3 --version
```
RHEL/Fedora
```
sudo dnf install python3-pip
sudo dnf install pipx
sudo dnf install python3-tk (again, not ALWAYS required, see above)
pip3 --version
```

Arch Linux
```
sudo pacman -S python-pip
sudo pacman -S pipx
sudo pacman -S python3-tk (again, not needed)
pip --version
```






### Then, install hardwaremon: ###

```
pip install hardwaremon
```

## Fixing the “Externally Managed Environment” Error ##

On some Linux distributions (especially Ubuntu and Debian-based systems), you may see an error like this when running:

```
pip install hardwaremon
```

Example:

```
error: externally-managed-environment
```

This happens because modern Linux systems protect the system Python installation to prevent accidental damage. Fortunately, there are several easy ways to work around this.

Recommended Method (Best Option): Use pipx

pipx installs applications in isolated environments and is the safest way to install HardwareMon.

Install pipx:

```
sudo apt install pipx
pipx ensurepath
```
After running ensurepat, you MUST restar your terminal or run:

```
source ~/.bashrc
```

Then install HardwareMon:

```
pipx install hardwaremon
```

Run it with:

```
hardwaremon
```

This method avoids conflicts with your system Python and is strongly recommended.

## Option 2: Use a Virtual Environment ##

You can install HardwareMon inside a Python virtual environment:

```
python3 -m venv hardwaremon-env
source hardwaremon-env/bin/activate
pip install hardwaremon
```

Run with:

```
hardwaremon
```

Deactivate later with:

```
deactivate
```

## Option 3: Force Installation (Not Recommended) ##

You can override the restriction with:

```
pip install hardwaremon –break-system-packages
```

This installs directly into the system Python.

## Warning: This can potentially break system tools that depend on Python. Only use this if you understand the risks. ##

If you’re unsure which method to use:

Use pipx — it’s the safest and easiest option.


I have still kept the instructions of Git cloning, if you prefer to install the script that way.

## GUI vs CLI Versions

Recently, I created a revamped version of HardwareMon, that seperates core hardware data into seperate pages, with icons to differentiate between them. It is recommended if you prefer a cleaner look, which supports themes and usage graphs. Now, when installing HardwareMon through Pip, you can launch the GUI by simply typing:

```
hardwaremon
```

But, if you prefer to check the CLI release out, that can be ran with:

```
hardwaremon_cli
```

The CLI version will still recieve updates, but not as heavily as the revamped HardwareMon, which im calling the GUI version, spending more time with it.



## Windows (PowerShell version) ##

Open PowerShell.

Run the script directly or use the provided .exe if available:

```
.\hardware-info.ps1
```

The Windows .exe was generated from the PowerShell script but is not maintained as actively as the source script. It may lack the latest bug fixes or features and is provided primarily for convenience.

# Notes #

The Windows version relies on CIM/WMI queries and may have limitations on certain hardware or older operating systems. The Linux Python version provides more extensive monitoring capabilities, including GPU lane and VRAM information for NVIDIA and AMD cards, as well as real-time graphical representations.

While the project can run as a standalone script or executable, it is recommended to use the scripts directly to ensure maximum compatibility and access to the latest updates.

The .sh script is also much more basic compared to the .py script on linux, since the .py script relies on Tkinter for graph drawings which Bash cannot use, and has not had as much attention compared to the .py version.

The .yml script only runs on the .py script.

# Contribution #

Contributions and suggestions are welcome. Please feel free to fork the repository and submit pull requests or report issues on the project’s issue tracker.

Made with ❤️ by Louis
