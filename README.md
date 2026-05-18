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

# About

HardwareMon is a modern hardware and performance monitoring application for Linux and Windows.

The project is designed to provide a fast, lightweight, and clean way to monitor real-time system activity without unnecessary complexity.

HardwareMon currently includes:

* Real-time CPU monitoring
* Memory and RAM statistics
* GPU monitoring
* Disk usage tracking
* Network upload/download monitoring
* Live process information
* Desktop graphical interfaces
* Command-line monitoring tools
* Native Linux packaging
* Windows installer support

The project currently contains:

* A stable Python/Tkinter edition
* A modern Flutter desktop edition under active development

---

# Features

## Real-Time Monitoring

Monitor live:

* CPU usage
* RAM usage
* GPU usage and temperature
* Disk usage
* Network throughput
* Running processes
* System resource statistics

---

## Cross Platform

HardwareMon supports:

* Linux
* Windows

---

## Native Packaging

HardwareMon integrates with:

* APT
* DNF
* WinGet
* GitHub Releases

---

## Lightweight Architecture

The Linux Flutter edition uses:

* Native Flutter desktop rendering
* A compiled backend API
* Native Linux package formats
* GitHub Releases distribution
* Cloudflare Pages repository hosting

---

# Installation

# Windows

## WinGet

```powershell
winget install LouisHinchliffe.HardwareMon
```

---

## Standalone Installer

Download the latest installer from:

```text
https://github.com/louisboii747/HardwareMon/releases
```

---

# Linux

# Ubuntu / Debian / Zorin OS

## Setup Repository

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/setup.sh | bash
```

---

## Install Stable Tkinter Edition

```bash
sudo apt install hardwaremon
```

---

## Install Flutter Edition

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/flutter.sh | bash
```

---

# Fedora / RPM-based Systems

## Install Stable RPM Edition

```bash
sudo dnf install \
https://github.com/louisboii747/HardwareMon/releases/latest/download/hardwaremon.rpm
```

---

## Install Flutter Edition

```bash
curl -fsSL https://hardwaremon.pages.dev/yum/install.sh | bash
```

---

# Usage

# GUI

Launch HardwareMon from your desktop applications menu or run:

```bash
hardwaremon-gui
```

---

# CLI

```bash
hardwaremon
```

---

# Flutter Edition

The Flutter edition is the next-generation HardwareMon interface.

Goals of the Flutter migration include:

* Modern desktop UI
* Improved responsiveness
* Better scalability
* Cross-platform consistency
* Cleaner architecture
* Advanced monitoring dashboards

The Flutter Linux edition uses a compiled backend binary bundled directly into the package.

This provides:

* Faster startup
* Easier installation
* Cleaner Linux packaging
* No Python runtime dependency for users

The original Python/Tkinter edition will continue receiving updates alongside the Flutter version.

---

# Updating

# Windows

```powershell
winget upgrade LouisHinchliffe.HardwareMon
```

---

# Ubuntu / Debian

## Stable Tkinter Edition

```bash
sudo apt update
sudo apt upgrade hardwaremon
```

---

## Flutter Edition

Re-run the installer script to install the latest release:

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/flutter.sh | bash
```

---

# Fedora / RPM-based Systems

## Stable RPM Tkinter Edition

```bash
sudo dnf install \
https://github.com/louisboii747/HardwareMon/releases/latest/download/hardwaremon.rpm
```

---

## Flutter Edition

Re-run the installer script to install the latest release:

```bash
curl -fsSL https://hardwaremon.pages.dev/yum/install.sh | bash
```

---

# Development

## Clone Repository

```bash
git clone https://github.com/louisboii747/HardwareMon.git
cd HardwareMon
```

---

## Python Dependencies

```bash
pip install psutil gputil pillow flask
```

---

## Flutter Development

```bash
cd flutter_gui
flutter pub get
flutter run -d linux
```

---

# Build System

HardwareMon uses automated CI/CD pipelines for:

* Linux DEB packaging
* Linux RPM packaging
* GitHub Releases
* Windows installers
* WinGet publishing
* Cloudflare Pages deployment

The project currently uses:

* GitHub Actions
* nfpm
* Flutter desktop
* PyInstaller
* Cloudflare Pages
* GitHub Releases

---

# Repository Hosting

HardwareMon repositories and installation scripts are hosted on Cloudflare Pages.

Large binary packages are distributed through GitHub Releases.

This architecture provides:

* Reliable global hosting
* Fast package downloads
* Lightweight repository infrastructure
* Automated release deployment

---

# Roadmap

Planned future improvements include:

* Advanced system graphs
* Historical performance tracking
* Process management tools
* Better GPU support
* Linux auto-update improvements
* Additional desktop effects and animations
* Expanded Windows support
* Native macOS support exploration

---

# Project Status

HardwareMon is under active development.

Both the legacy Python implementation and the modern Flutter edition are continuing to receive updates.

The Python/Tkinter version is not deprecated and will continue receiving maintenance and feature improvements.

---

# Links

## GitHub Repository

[https://github.com/louisboii747/HardwareMon](https://github.com/louisboii747/HardwareMon)

---

## Releases

[https://github.com/louisboii747/HardwareMon/releases](https://github.com/louisboii747/HardwareMon/releases)

---

## Linux Repository Hosting

[https://hardwaremon.pages.dev](https://hardwaremon.pages.dev)
