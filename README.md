# HardwareMon

[![Release](https://img.shields.io/github/v/release/louisboii747/HardwareMon)](https://github.com/louisboii747/HardwareMon/releases)
![Downloads](https://img.shields.io/github/downloads/louisboii747/HardwareMon/total)
![Python](https://img.shields.io/badge/Python-3.x-blue?logo=python)
![Flutter](https://img.shields.io/badge/Flutter-desktop-02569B?logo=flutter)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI/CD-2088FF?logo=github-actions)
![Cloudflare Pages](https://img.shields.io/badge/Hosted_on-Cloudflare_Pages-orange?logo=cloudflare)
![Linux](https://img.shields.io/badge/Linux-supported-2bbc8a?logo=linux)
![Windows](https://img.shields.io/badge/Windows-supported-0078D6?logo=windows)
![APT](https://img.shields.io/badge/APT-supported-red?logo=debian)
![DNF](https://img.shields.io/badge/DNF-supported-294172?logo=fedora)
![winget](https://img.shields.io/badge/WinGet-supported-0078D4?logo=windows)

Modern system monitoring for Linux and Windows.

## About

HardwareMon is a modern system monitoring tool for Linux and Windows, designed to provide a clear, real-time view of your computer’s hardware and performance.

It offers detailed monitoring for:

- CPU
- Memory
- Disk usage
- GPU activity
- Network usage
- System statistics
- Processes and live resource information

HardwareMon includes both graphical and command-line interfaces, allowing you to choose between a clean visual dashboard or deeper terminal-based system inspection.

The project focuses on:

- Performance
- Clarity
- Ease of use
- Native platform integration
- Lightweight monitoring without unnecessary complexity

---

# Platforms

## Linux

HardwareMon is distributed through native package repositories:

- APT (Debian, Ubuntu, Zorin OS, etc.)
- DNF (Fedora, RHEL-based systems)

This allows installation and updates directly through your system package manager.

## Windows

HardwareMon is available through:

- Standalone graphical installer
- Windows Package Manager (WinGet)

---

# Installation

# Windows

## WinGet

```powershell
winget install LouisHinchliffe.HardwareMon
```

## Standalone Installer

Download the latest installer from:

```text
https://github.com/louisboii747/HardwareMon/releases
```

---

# Linux

# APT (Debian / Ubuntu / Zorin)

## Automatic Setup

```bash
curl -fsSL https://hardwaremon.pages.dev/apt/setup.sh | sudo bash
```

## Install

```bash
sudo apt install hardwaremon
```

---

## Manual APT Setup

```bash
echo "deb [trusted=yes] https://hardwaremon.pages.dev/apt stable main" \
| sudo tee /etc/apt/sources.list.d/hardwaremon.list
```

```bash
sudo apt update
```

```bash
sudo apt install hardwaremon
```

---

# DNF (Fedora / RHEL)

## Add Repository

```bash
sudo dnf install dnf-plugins-core
```

```bash
sudo dnf config-manager addrepo \
--from-repofile=https://hardwaremon.pages.dev/yum/hardwaremon.repo
```

## Install

```bash
sudo dnf install hardwaremon
```

---

# Usage

## GUI

Launch HardwareMon from your desktop applications menu or run:

```bash
hardwaremon-gui
```

## CLI

```bash
hardwaremon
```

---

# Flutter Edition

A next-generation version of HardwareMon is currently being developed using Flutter.

The goal of the Flutter edition is to provide:

- A significantly more modern interface
- Improved responsiveness
- Cross-platform desktop support
- Better long-term scalability
- Advanced real-time monitoring dashboards

The current Python/Tkinter-based HardwareMon applications will continue receiving updates alongside the Flutter version.

---

## Current Flutter Package Status

### APT

The Flutter version is currently installable on APT-based distributions using:

```bash
sudo apt install hardwaremon-flutter
```

### DNF / RPM

```
sudo dnf install hardwaremon-flutter
```

⚠️ The Flutter RPM/DNF package is currently experimental and not fully working yet.

The package builds successfully, but runtime issues are still being resolved for Fedora/RHEL systems.

Until this is completed, the standard HardwareMon package is recommended on DNF-based systems.

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

## WinGet

```powershell
winget upgrade LouisHinchliffe.HardwareMon
```

---

# PyPI Cross-Platform Fallback (Deprecated)

HardwareMon can still be installed through PyPI:

```bash
pip install hardwaremon
```

Or with pipx:

```bash
pipx install hardwaremon
```

However:

- PyPI releases may not contain the newest features
- Native Linux packages are the preferred installation method
- Repository packages receive the fastest updates and improvements

---

# Development Notes

When running the Linux GUI version inside VS Code or a virtual environment, you may encounter missing Pillow/PIL module errors.

Install Pillow using:

```bash
pip install pillow
```

---

# Project Status

HardwareMon is under active development.

Both the legacy Python implementation and the new Flutter edition are continuing to receive updates while the Flutter version receives development.

The legacy Tkinter versions will NOT be deprecated. It will continue receiveing development.
