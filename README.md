# HardwareMon

<p align="center">
  <img src="https://raw.githubusercontent.com/louisboii747/HardwareMon/main/Untitled%20design.png" width="128" alt="HardwareMon Logo">
</p>

<p align="center">
  <b>Modern cross-platform system monitoring for Linux and Windows.</b>
</p>

<p align="center">
  Real-time hardware analytics, cinematic Flutter UI, native Linux packaging,
  Windows installers, automated repositories, and bundled backend architecture.
</p>

---

<p align="center">

<img src="https://img.shields.io/github/v/release/louisboii747/HardwareMon" alt="Release">
<img src="https://img.shields.io/github/downloads/louisboii747/HardwareMon/total" alt="Downloads">

<img src="https://img.shields.io/badge/Linux-supported-2bbc8a?logo=linux" alt="Linux">
<img src="https://img.shields.io/badge/Windows-supported-0078D6?logo=windows" alt="Windows">

<img src="https://img.shields.io/badge/Flutter-desktop-02569B?logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/FastAPI-backend-009688?logo=fastapi" alt="FastAPI">

<img src="https://img.shields.io/badge/APT-supported-red?logo=debian" alt="APT">
<img src="https://img.shields.io/badge/DNF-supported-294172?logo=fedora" alt="DNF">
<img src="https://img.shields.io/badge/AUR-supported-1793D1?logo=arch-linux" alt="AUR">
<img src="https://img.shields.io/badge/WinGet-supported-0078D4?logo=windows" alt="WinGet">

<img src="https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions" alt="GitHub Actions">
<img src="https://img.shields.io/badge/Cloudflare_Pages-hosted-orange?logo=cloudflare" alt="Cloudflare Pages">

</p>

---

# Website

🌐 [https://gethardwaremon.pages.dev](https://gethardwaremon.pages.dev)

The HardwareMon website contains:

* Downloads
* Screenshots
* Installation guides
* Development updates
* Release information
* Linux repository setup
* Future documentation

---

# Features

## Monitoring

* Real-time CPU monitoring
* RAM and memory analytics
* GPU monitoring
* Disk usage monitoring
* Network monitoring
* Live process monitoring
* Animated telemetry graphs
* Real-time metric history
* Expandable monitoring cards
* Immersive focus-mode analytics views

---

## User Interface

* Modern Flutter desktop interface
* Cinematic dark workstation aesthetic
* Smooth animations and transitions
* Floating glass-style UI panels
* Animated dashboards
* Responsive multi-page layout
* Sidebar navigation system
* Interactive telemetry cards
* Cross-platform desktop architecture

---

## Security & Diagnostics (Slowly being introduced)

* VirusTotal process scanning integration
* SHA256 process hashing
* Suspicious executable detection
* Secure API-based process analysis

---

## Distribution & Packaging

* Native Linux DEB packages
* Native Linux RPM packages
* APT repository support
* DNF repository support
* AUR support
* Windows installer support
* WinGet support
* GitHub Releases automation
* Cloudflare-hosted repositories

---


# HardwareMon Evolution

HardwareMon originally began as a small Python/Tkinter hardware monitor created during early experimentation with Linux system telemetry.

The project has since been completely rebuilt into a modern cross-platform monitoring platform using:

* Flutter Desktop
* FastAPI
* LibreHardwareMonitor
* Real-time telemetry APIs
* Automated CI/CD pipelines
* Native Linux packaging
* Windows installer infrastructure

The legacy Tkinter interface and older Python GUI implementations have now been fully removed from the project and are no longer maintained.

HardwareMon now uses a unified Flutter frontend architecture across Linux and Windows with a bundled backend system for telemetry collection and process analytics.

---

# Platform Support

| Platform        | Status      | Distribution       |
| --------------- | ----------- | ------------------ |
| Windows         | ✅ Supported | Installer / WinGet |
| Ubuntu / Debian | ✅ Supported | APT                |
| Fedora          | ✅ Supported | DNF                |
| Arch Linux      | ⌛ Coming Soon | AUR                |
| macOS           | 🚧 Planned  | Future             |

---

# Installation

# Windows

## WinGet

```powershell
winget install LouisHinchliffe.HardwareMon
```

---

## Manual Installer

Download the latest Windows installer from:

[https://github.com/louisboii747/HardwareMon/releases](https://github.com/louisboii747/HardwareMon/releases)

---

# Ubuntu / Debian

Add the HardwareMon repository:

```bash
echo "deb [trusted=yes] https://hardwaremon.pages.dev/apt stable main" \
| sudo tee /etc/apt/sources.list.d/hardwaremon.list
```

Update repositories:

```bash
sudo apt update
```

Install HardwareMon:

```bash
sudo apt install hardwaremon
```

---

# Fedora

Add the repository:

```bash
sudo dnf config-manager addrepo \
--from-repofile=https://hardwaremon.pages.dev/yum/hardwaremon.repo
```

Install HardwareMon:

```bash
sudo dnf install hardwaremon
```

---

# Arch Linux (Coming Soon!)

## yay

```bash
yay -S hardwaremon-bin
```

## paru

```bash
paru -S hardwaremon-bin
```

---

# Updating

## Windows

```powershell
winget upgrade LouisHinchliffe.HardwareMon
```

---

## Ubuntu / Debian

```bash
sudo apt update
sudo apt upgrade
```

---

## Fedora

```bash
sudo dnf makecache --refresh # refreshes repository data, needed for updating on DNF
sudo dnf update
```

---

## Arch Linux (Coming Soon)

```bash
yay -Syu
```

---

# Modern Architecture

HardwareMon now uses a fully modular frontend/backend architecture.

## Frontend Layer

Built entirely with Flutter Desktop:

* Windows support
* Linux support
* Shared UI codebase
* Animated workstation-style interface
* Realtime telemetry rendering
* Expandable analytics views
* Multi-page navigation system
* Cross-platform desktop framework

---

## Backend Layer

Built using FastAPI and Python telemetry services:

* Hardware telemetry APIs
* Process monitoring
* System analytics
* Temperature monitoring
* Live metric streaming
* Process security scanning
* JSON-based telemetry endpoints

The backend is bundled directly with release builds and automatically launched by the Flutter application.

---

# Windows Version

The Windows version is actively evolving into a cinematic workstation-style monitoring experience.

Current Windows development includes:

* Animated dashboard system
* Interactive telemetry cards
* Focus-mode analytics views
* Multi-page navigation architecture
* Live graph rendering
* Real hardware telemetry
* LibreHardwareMonitor integration
* Acrylic/glass-inspired UI styling
* Smooth animated transitions

The Windows UI is built using Flutter Desktop with a modular architecture designed for future scalability.

---

# Linux Distribution

HardwareMon includes fully automated Linux packaging infrastructure.

Supported distribution methods:

* APT repositories
* DNF repositories
* AUR packages
* Direct GitHub Releases

Linux packages include:

* Native desktop entries
* Application icons
* Bundled backend binaries
* Automatic backend launching
* Repository metadata
* Automated updates through system package managers

---

# Legacy Components

The following legacy components have been removed:

* Tkinter GUI
* Older Python desktop interfaces
* Legacy launcher systems
* Previous monolithic UI architecture

Any remaining issues, references, or deprecated code related to these legacy systems are considered unsupported and may be ignored during development moving forward.

---

# CI/CD Infrastructure

HardwareMon uses automated GitHub Actions pipelines for:

* Linux DEB packaging
* Linux RPM packaging
* AUR publishing
* Windows installer generation
* WinGet publishing
* GitHub Releases
* Cloudflare Pages deployment
* Repository metadata generation

Technologies used include:

* Flutter Desktop
* FastAPI
* PyInstaller
* GitHub Actions
* nfpm
* Cloudflare Pages

---

# Development

## Clone Repository

```bash
git clone https://github.com/louisboii747/HardwareMon.git

cd HardwareMon
```

---

# Flutter Development

```bash
cd flutter_gui

flutter pub get

flutter run -d windows
```

Linux:

```bash
flutter run -d linux
```

---

# Backend Development

```bash
cd backend_fastapi

pip install fastapi uvicorn psutil

python main.py
```

---

# Roadmap

Planned future improvements include:

* Historical monitoring database
* Long-term analytics
* Per-core CPU visualisations
* Expanded GPU telemetry
* Remote monitoring support
* System tray integration
* Custom dashboard layouts
* Plugin architecture
* Detachable analytics windows
* Alerts and notifications
* Native macOS exploration

---

# Project Status

HardwareMon is under active development.

The project is evolving into a modern cross-platform monitoring platform focused on:

* performance
* desktop experience
* packaging automation
* scalable architecture
* cinematic UI design
* real-time telemetry systems

---

# Links

## GitHub Repository

[https://github.com/louisboii747/HardwareMon](https://github.com/louisboii747/HardwareMon)

---

## Releases

[https://github.com/louisboii747/HardwareMon/releases](https://github.com/louisboii747/HardwareMon/releases)

---

## Website

[https://gethardwaremon.pages.dev](https://gethardwaremon.pages.dev)
