# HardwareMon

## About

HardwareMon is a modern system monitoring tool for Linux and Windows, designed to give a clear, real time view of your computer’s hardware and performance.

It provides detailed insights into CPU, memory, disk, GPU, network, and system activity through both a graphical interface and command line tools. Whether you want a clean visual overview or deeper technical information, HardwareMon makes it easy to understand what your system is doing at any moment.

On Linux, HardwareMon is distributed as a native package through APT and DNF repositories, allowing simple installation and updates directly from your system package manager.

On Windows, HardwareMon is available as a standalone graphical installer and through Windows Package Manager (WinGet).

The project focuses on performance, clarity, and ease of use while providing powerful monitoring features without unnecessary complexity.

---

# Installation

## Windows

### WinGet

```powershell
winget install LouisHinchliffe.HardwareMon
```

### Standalone Installer

Download the latest installer from the GitHub Releases page:

```text
https://github.com/louisboii747/HardwareMon/releases
```

---

## Linux

### APT Debian Ubuntu Zorin

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/setup.sh | sudo bash
```

```bash
sudo apt install hardwaremon
```

### Manual APT Setup

```bash
echo "deb [trusted=yes] https://hardwaremon.pages.dev/apt stable main" | sudo tee /etc/apt/sources.list.d/hardwaremon.list
```

```bash
sudo apt update
```

```bash
sudo apt install hardwaremon
```
### Usage
You can run the either the GUI from your applications list or by running:
```
hardwaremon-gui
```
In the terminal. For CLI:

```
hardwaremon
```

### DNF Fedora RHEL

```bash
sudo dnf install dnf-plugins-core
```

```bash
sudo dnf config-manager --add-repo https://hardwaremon.pages.dev/yum/hardwaremon.repo
```

```bash
sudo dnf install hardwaremon
```

### Usage
You can run the either the GUI from your applications list or by running:
```
hardwaremon-gui
```
In the terminal. For CLI:

```
hardwaremon
```

---

## PyPI Cross Platform Fallback

You can still install HardwareMon using pip:

```bash
pip install hardwaremon
```

Or with pipx:

```bash
pipx install hardwaremon
```

PyPI may not always contain the newest features and improvements.

For the best Linux experience, use the APT or DNF repositories.

---

# Updating

## APT

```bash
sudo apt update && sudo apt upgrade hardwaremon
```

## DNF

```bash
sudo dnf upgrade --refresh
sudo dnf upgrade hardwaremon
```

## PyPI

```bash
pipx upgrade hardwaremon
```

## WinGet

```powershell
winget upgrade LouisHinchliffe.HardwareMon
```

---

# Development Notes

When running the Linux GUI version inside VS Code, you may encounter a PIL module not found error.

Create a virtual environment and install Pillow:

```bash
pip install pillow
```
