# HardwareMon

<p align="center">
  <img src="https://raw.githubusercontent.com/louisboii747/HardwareMon/main/Untitled design.png" width="128" alt="HardwareMon Logo">
</p>

<p align="center">
  <b>Modern system monitoring for Linux and Windows.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/louisboii747/HardwareMon" alt="Release">
  <img src="https://img.shields.io/github/downloads/louisboii747/HardwareMon/total" alt="Downloads">
  <img src="https://img.shields.io/badge/Linux-supported-2bbc8a?logo=linux" alt="Linux">
  <img src="https://img.shields.io/badge/Windows-supported-0078D6?logo=windows" alt="Windows">
  <img src="https://img.shields.io/badge/Python-3.x-blue?logo=python" alt="Python">
  <img src="https://img.shields.io/badge/Flutter-desktop-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions" alt="GitHub Actions">
  <img src="https://img.shields.io/badge/Cloudflare_Pages-hosted-orange?logo=cloudflare" alt="Cloudflare Pages">
  <img src="https://img.shields.io/badge/APT-supported-red?logo=debian" alt="APT">
  <img src="https://img.shields.io/badge/DNF-supported-294172?logo=fedora" alt="DNF">
  <img src="https://img.shields.io/badge/Flatpak-supported-4A90D9?logo=flatpak" alt="Flatpak">
  <img src="https://img.shields.io/badge/WinGet-supported-0078D4?logo=windows" alt="WinGet">
</p>

<p align="center">
  🌐 <b>Official Website:</b><br>
  <a href="https://gethardwaremon.pages.dev">https://gethardwaremon.pages.dev</a>
</p>

<p align="center">
  The HardwareMon website contains downloads, screenshots, installation guides,
  development updates, release information, and future project documentation.
</p>

---

# Features

* Real-time CPU, RAM, GPU, disk and network monitoring
* Modern Flutter desktop interface
* Live process monitoring
* VirusTotal process scanning integration
* Native Linux packaging
* APT, DNF and AUR repositories
* Flatpak support
* Windows installer + WinGet support
* Automated GitHub Releases
* Cross-platform architecture
* GitHub Actions CI/CD pipelines
* Cloudflare-hosted package repositories

---

# Platform Support

| Platform        | Status      | Installation       |
| --------------- | ----------- | ------------------ |
| Windows         | ✅ Supported | WinGet / Installer |
| Ubuntu / Debian | ✅ Supported | APT                |
| Fedora          | ✅ Supported | DNF                |
| Arch Linux      | ✅ Supported | AUR / yay          |
| Flatpak         | ✅ Supported | Universal Linux    |
| macOS           | 🚧 Planned  | -                  |

---

# Quick Install

## Windows

### WinGet

```powershell
winget install LouisHinchliffe.HardwareMon
```

---

## Arch Linux

### yay

```bash
yay -S hardwaremon-bin
```

---

## Ubuntu / Debian Systems

### Flutter Edition

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/flutter.sh | bash
```

### Legacy Tkinter Edition

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/setup.sh | bash
sudo apt install hardwaremon
```

---

## Fedora / RPM-based Systems

### Flutter Edition

```bash
curl -fsSL https://hardwaremon.pages.dev/yum/install.sh | bash
```

### Legacy RPM Edition

```bash
sudo dnf install \
https://github.com/louisboii747/HardwareMon/releases/latest/download/hardwaremon.rpm
```

---

## Flatpak

```bash
curl -L \
https://github.com/louisboii747/HardwareMon/releases/latest/download/hardwaremon.flatpak \
-o /tmp/hardwaremon.flatpak && \
flatpak install --user -y /tmp/hardwaremon.flatpak
```

Launch:

```bash
flatpak run com.hardwaremon.HardwareMon
```

---

# Updating

---

## Windows

```powershell
winget upgrade LouisHinchliffe.HardwareMon
```

---

## Arch Linux

```bash
yay -Syu hardwaremon-bin
```

---

## Ubuntu / Debian

### Flutter Edition

Re-run the installer script:

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/flutter.sh | bash
```

### Legacy Tkinter Edition

```bash
sudo apt update
sudo apt upgrade hardwaremon
```

---

## Fedora / RPM-based Systems

### Flutter Edition

Re-run the installer script:

```bash
curl -fsSL https://hardwaremon.pages.dev/yum/install.sh | bash
```

### Legacy RPM Edition

```bash
sudo dnf upgrade hardwaremon
```

---

## Flatpak

```bash
flatpak update
```

---

# VirusTotal Integration

HardwareMon includes optional VirusTotal integration for scanning running processes.

Features include:

* SHA256 process hash scanning
* Process reputation lookups
* Suspicious executable detection
* Secure API-based analysis
* Optional personal API key support

This allows HardwareMon to help identify potentially malicious or suspicious software directly from the monitoring interface.

---

# Flutter Edition

HardwareMon is actively transitioning toward a modern Flutter-based desktop interface.

The Flutter edition includes:

* Modern desktop UI
* Smooth animations and transitions
* Expanded monitoring dashboards
* Better scalability
* Cross-platform consistency
* Bundled backend architecture

The Linux Flutter builds bundle the backend directly into the application package for simpler installation and deployment.

The original Python/Tkinter edition continues to receive maintenance and updates alongside the Flutter edition.

---

# Development

## Clone Repository

```bash
git clone https://github.com/louisboii747/HardwareMon.git
cd HardwareMon
```

---

## Flutter Development

```bash
cd flutter_gui
flutter pub get
flutter run -d linux
```

---

## Python Dependencies

```bash
pip install psutil gputil pillow flask
```

---

# Build & Release Infrastructure

HardwareMon uses automated CI/CD pipelines for:

* DEB packaging
* RPM packaging
* Flatpak packaging
* AUR releases
* GitHub Releases
* Windows installer generation
* WinGet publishing
* Cloudflare Pages deployment

Technologies used include:

* Flutter Desktop
* Python
* PyInstaller
* GitHub Actions
* Flatpak Builder
* nfpm
* Cloudflare Pages

---

# Roadmap

Planned future improvements include:

* Historical monitoring and analytics
* Advanced interactive graphs
* Remote monitoring support
* System tray integration
* Custom dashboards
* Expanded Windows support
* Official Flathub publishing
* Plugin architecture
* Native macOS support exploration

---

# Project Status

HardwareMon is under active development.

Both the legacy Python implementation and the modern Flutter edition continue to receive updates and improvements.

---

# Links

## GitHub Repository

https://github.com/louisboii747/HardwareMon

---

## Releases

https://github.com/louisboii747/HardwareMon/releases

---

## Website

https://gethardwaremon.pages.dev


---

