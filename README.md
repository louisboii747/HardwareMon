# HardwareMon

<p align="center">
  <img src="https://raw.githubusercontent.com/louisboii747/HardwareMon/main/Untitled%20design.png" width="128" alt="HardwareMon Logo">
</p>

<p align="center">
  <b>Modern cross-platform system monitoring for Linux, macOS and Windows.</b>
</p>

<p align="center">
  Real-time hardware analytics, historical analytics via SQLite, cinematic Flutter UI, native Linux packaging,
  Windows installers, automated repositories, and bundled backend architecture.
</p>

<p align="center">
  <a href="https://sourceforge.net/p/hardwaremon/"><img alt="Download HardwareMon" src="https://sourceforge.net/sflogo.php?type=18&amp;group_id=4105016" width=200></a>
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
<img src="https://img.shields.io/badge/macOS-supported-black?logo=apple" alt="macOS">
<img src="https://img.shields.io/badge/AUR-supported-1793D1?logo=arch-linux" alt="AUR">
<img src="https://img.shields.io/badge/WinGet-supported-0078D4?logo=windows" alt="WinGet">

<img src="https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions" alt="GitHub Actions">

<a href="https://hardwaremon-site.pages.dev/">
  <img src="https://img.shields.io/badge/Website-hardwaremon.pages.dev-orange?logo=cloudflare" alt="Website">
</a>

</p>

---

## Screenshots

<table>
  <tr>
    <th>Dashboard</th>
    <th>Processes</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/ee0f186d-75f6-4700-b29e-c6f8ff2ecaad" alt="Dashboard" width="100%">
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/c9186d9b-5b33-4294-a734-3ce8ce5d898d" alt="Processes" width="100%">
    </td>
  </tr>
  <tr>
    <th>Performance</th>
    <th>Settings</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/cc65ea00-37a5-458d-8d8e-b330b9177668" alt="Performance" width="100%">
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/2950baf1-f103-4cc2-856b-7bcb3480e3ba" alt="Settings" width="100%">
    </td>
  </tr>
</table>





## What is HardwareMon?

HardwareMon is a modern cross-platform system monitor for Linux, macOS and Windows built with Flutter and FastAPI.

It provides:

- Real-time hardware telemetry
- Historical analytics
- Process monitoring and management
- Native APT, DNF and WinGet distribution
- Automated updates and packaging
- Modern desktop UI

<p align="center">
⭐ If you find HardwareMon useful, consider starring the repository. Every star helps!
</p>

## Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Why HardwareMon?](#why-hardwaremon)
- [Installation](#installation)
- [Windows](#windows)
- [Linux APT and DNF](#linux-installation)
- [macOS](#macos-apple-silicon-only)
- [Android Companion](#android-companion)
- [Android Features](#android-features)
- [Remote Monitoring](#remote-monitoring)
- [Architecture](#modern-architecture)
- [Updating HardwareMon](#updating)
- [Development](#development)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Links](#links)


## Quick Start

### Windows
```
winget install LouisHinchliffe.HardwareMon
```
### Linux

➡️ [Jump to Linux Installation](#linux-installation)



### macOS

Download the latest DMG from GitHub Releases.

➡️ [Learn more about HardwareMon on macOS](#macos-apple-silicon-only)

### Android

Download the latest HardwareMon Companion APK from GitHub Releases.

Pair it with your desktop over your local network to monitor your PC in real time.

➡️ Learn more about the Android Companion below.

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

## Distribution & Packaging

* Native Linux DEB packages
* Native Linux RPM packages
* APT repository support
* DNF repository support
* Windows installer support
* WinGet support
* GitHub Releases automation

---

## Why HardwareMon?

Most system monitoring tools either focus on raw data or dated interfaces.

HardwareMon aims to combine real-time telemetry, historical analytics, modern desktop design, and native Linux/Windows distribution into a single application.




| Feature                    | HardwareMon | Task Manager | Htop |
| -------------------------- | ----------- | ------------ | ---- |
| CPU Monitoring             | ✅           | ✅            | ✅    |
| Historical Analytics       | ✅           | ❌            | ❌    |
| Process Management         | ✅           | ✅            | ✅    |
| Modern UI                  | ✅           | ⚠️           | ❌    |
| Linux Package Repositories | ✅           | ❌            | ❌    |
| Windows Installer          | ✅           | Built-in     | ❌    |



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
| Flatpak         | ⚠️ Experimental | Flatpak         |
| Arch Linux      | 🚧 Planned | AUR                  |
| macOS           | ✅ Apple Silicon only  | DMG from Github Releases              |
| Android      | 🚧 In Development | APK                  |

---

# Installation

# Windows

## WinGet

```powershell
winget install LouisHinchliffe.HardwareMon
```

When launching HardwareMon, be sure to click 'Yes' to any UAC prompts for LibreHardwareMonitor.exe, to ensure full functionality like process management and temperature monitoring.
The app will still function if you choose 'No', as the app will then fall back to ```psutil``` for analytics, but choosing 'No' is not recommended due to LHM being required for some features.

---

## Manual Installer

Download the latest Windows installer from:

[https://github.com/louisboii747/HardwareMon/releases](https://github.com/louisboii747/HardwareMon/releases)

As mentioned above in the Winget install method, when launching HardwareMon be sure to click 'Yes' to any UAC prompts for LibreHardwareMonitor.exe, to ensure full functionality like process management and temperature monitoring.
The app will still function if you choose 'No', as the app will then fall back to ```psutil``` for analytics, but choosing 'No' is not recommended due to LHM being required for some features.

---

# Linux Installation

### Debian / Ubuntu distributions (APT)

Import the HardwareMon repository signing key:

```bash
curl -fsSL https://pub-f6d988b71b7f48198af4ccbfb6026ba9.r2.dev/hardwaremon-public.asc \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hardwaremon.gpg > /dev/null
```

Add the repository:

```bash
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hardwaremon.gpg] https://pub-f6d988b71b7f48198af4ccbfb6026ba9.r2.dev/apt stable main" | \
sudo tee /etc/apt/sources.list.d/hardwaremon.list
```

Install HardwareMon:

```bash
sudo apt update
sudo apt install hardwaremon
```


### Fedora/RHEL distributions (DNF)

Create the repository configuration:

```bash
sudo tee /etc/yum.repos.d/hardwaremon.repo > /dev/null <<EOF
[hardwaremon]
name=HardwareMon
baseurl=https://pub-f6d988b71b7f48198af4ccbfb6026ba9.r2.dev/yum
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pub-f6d988b71b7f48198af4ccbfb6026ba9.r2.dev/hardwaremon-public.asc
EOF
```

Install HardwareMon:

```bash
sudo dnf makecache
sudo dnf install hardwaremon
```



# Flatpak (Arch, APT and DNF)

Download the latest `hardwaremon.flatpak` file from GitHub Releases.

Install the package:

```bash
flatpak install hardwaremon.flatpak
```

Launch HardwareMon:

```bash
flatpak run com.hardwaremon.HardwareMon
```

# macOS (Apple Silicon Only)

HardwareMon offers a DMG file downloadable from Github Releases. This DMG does not currently support x64 based macs, as the build process targets ARM based M1+ systems only.
There are plans to port the app over to the App Store on macOS. x64 versions for Intel macs will arrive soon.

| Architecture | Support |
|--------------|---------|
| Apple Silicon (M1) | ✅ |
| Apple Silicon (M2) | ✅ |
| Apple Silicon (M3) | ✅ |
| Apple Silicon (M4) | ✅ |
| Intel (x86_64) | ❌ |

> Tested on Apple Silicon hardware. Intel Mac support is planned for a future release.

# Android Companion

HardwareMon includes an Android companion application that connects to your desktop over your local network.

The companion provides live telemetry without requiring cloud services or external accounts.

Simply pair your Android device with your desktop and monitor your system from anywhere on your home network.

# Android Features

The Android companion includes:

* Live CPU usage
* Live RAM usage
* GPU monitoring
* CPU temperatures
* Disk usage
* Network activity
* Device information
* Real-time graphs
* Secure local pairing
* Automatic desktop discovery
* Material 3 interface
* Dark mode

* # Remote Monitoring

HardwareMon uses a local-first architecture.

The Android app communicates directly with your desktop over your LAN.

Features include:

* Automatic desktop discovery
* Persistent trusted devices
* Low-latency updates
* No cloud account required
* Private local communication
* Future remote access support


# Updating

## Windows

```powershell
winget upgrade LouisHinchliffe.HardwareMon
```

---

## Ubuntu / Debian

```bash
sudo apt update
sudo apt upgrade hardwaremon
```

---

## Fedora

```bash
sudo dnf makecache --refresh # refreshes repository data, needed for updating on DNF
sudo dnf upgrade hardwaremon
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

## Android Layer

Built with modern Android technologies:

* Native Android application
* Material Design 3
* Local device discovery
* Persistent pairing
* Real-time telemetry
* WebSocket communication
* Responsive tablet support

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
cd hardwaremon_app

flutter pub get

uvicorn main:app --reload

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

uvicorn main:app --reload
```

---

# Roadmap

Planned future improvements include:


* Remote monitoring support
* System tray integration
* Custom dashboard layouts
* Plugin architecture
* Detachable analytics windows
* Native macOS exploration

## Android

Planned improvements include:

* Home screen widgets
* Material You theming
* Push notifications
* Multiple desktop support
* Historical analytics
* Wear OS support
* Quick Settings tile
* Background monitoring

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

# Contributing

Contributions will always be welcome to HardwareMon. Feel free to create a feature request in Issues, or submit a PR! I'd love to see your changes, fixes or ideas!

---

# Links

## GitHub Repository

[https://github.com/louisboii747/HardwareMon](https://github.com/louisboii747/HardwareMon)

---

## Releases

[https://github.com/louisboii747/HardwareMon/releases](https://github.com/louisboii747/HardwareMon/releases)

---

## Website

[https://hardwaremon-site.pages.dev/](https://hardwaremon-site.pages.dev/)

The HardwareMon website contains:

* Downloads
* Screenshots
* Installation guides
* Development updates
* Release information
* Linux repository setup
* Future documentation
