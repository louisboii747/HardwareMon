# HardwareMon

<p align="center">
  <img src="https://raw.githubusercontent.com/louisboii747/HardwareMon/main/Untitled%20design.png" width="128" alt="HardwareMon Logo">
</p>

<p align="center">
  <b>Modern system monitoring for Android, Linux, macOS and Windows.</b>
</p>

<p align="center">
  Real-time hardware analytics, a native Android dashboard, historical analytics via SQLite, cinematic desktop UI,
  native Linux packaging, Windows installers, automated repositories, and bundled desktop telemetry architecture.
</p>

<p align="center">
  <a href="https://peerpush.com/p/hardwaremon" target="_blank" rel="noopener">
    <img
      src="https://peerpush.com/p/hardwaremon/badge.png"
      alt="HardwareMon on PeerPush"
      width="230"
    />
  </a>
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
<img src="https://img.shields.io/badge/Android-supported-3DDC84?logo=android&amp;logoColor=white" alt="Android">

<img src="https://img.shields.io/badge/Flutter-desktop-02569B?logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/FastAPI-backend-009688?logo=fastapi" alt="FastAPI">

<img src="https://img.shields.io/badge/APT-supported-red?logo=debian" alt="APT">
<img src="https://img.shields.io/badge/DNF-supported-294172?logo=fedora" alt="DNF">
<img src="https://img.shields.io/badge/macOS-supported-black?logo=apple" alt="macOS">
<img src="https://img.shields.io/badge/AUR-supported-1793D1?logo=arch-linux" alt="AUR">
<img src="https://img.shields.io/badge/WinGet-supported-0078D4?logo=windows" alt="WinGet">

<img src="https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions" alt="GitHub Actions">

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

HardwareMon is a modern system monitor for Android, Linux, macOS and Windows. The desktop application uses Flutter and FastAPI, while Android has a native Kotlin and Jetpack Compose application that monitors the phone or tablet directly.

HardwareMon processes monitoring and benchmark information locally. See the
[Privacy Policy](PRIVACY.md) for details.

It provides:

- Real-time hardware telemetry
- Native on-device Android telemetry
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
- [Android](#android)
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

Download the latest signed HardwareMon Android APK from GitHub Releases and install it on your phone or tablet.

HardwareMon immediately displays telemetry for the Android device itself. No account, server, or setup flow is required.

➡️ [Learn more about HardwareMon for Android](#android).

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
* Automatic Gaming Mode session capture

## System Intelligence

* Telemetry-derived health scoring with performance, memory, thermal, power,
  battery, and storage signals where each platform exposes them
* Balanced, Performance, Quiet, Efficiency, and Reliability monitoring lenses
* Local session journals for capturing useful baselines and workload snapshots
* Bottleneck detection, trend observations, and explicit unavailable states
* Shareable or copyable session reports with no automatic upload
* Configurable watch thresholds and de-duplicated event history

---

## Benchmark Mode

HardwareMon includes a lightweight local benchmark for CPU single-thread and
multi-thread performance, memory throughput, and temporary-file disk read/write
performance. Runs happen in the background, can be cancelled, require no
administrator or root privileges, and save comparison-ready results locally.

Scores are HardwareMon benchmark scores and are not comparable with Geekbench,
Cinebench, or other benchmark suites. Compare runs using the same benchmark
version and similar conditions; thermals, power mode, battery state, and
background activity can all affect results.

Completed runs include an offline comparison view with percentile, matching
hardware averages, ranking statistics, performance insights, and score charts.
Comparisons can be filtered by identical CPU, CPU + GPU, CPU family, platform,
or all version-compatible results stored locally.

Online comparison is designed as an optional provider and is not connected in
this release. HardwareMon never uploads a result automatically; after a run it
asks for explicit anonymous-submission consent, and the application continues
to work fully offline. The future cloud request/response and privacy contract is
documented in [docs/benchmark-cloud-api.md](docs/benchmark-cloud-api.md).

---

## Gaming Mode

Gaming Mode automatically watches the local process list for known game
executables, starts a session when a game launches, samples existing
HardwareMon telemetry while the game is running, and finishes the session when
all detected game processes exit.

Completed sessions are stored locally in SQLite with duration, platform,
HardwareMon version, average CPU/GPU/RAM usage, CPU/GPU temperatures, peak
temperatures, peak RAM/GPU/CPU usage, CPU clock, CPU/GPU power, and sample
counts. The desktop Gaming page includes a live recording view, session
history, full session details, and aggregate statistics such as most played
game, longest session, total gaming hours, average session length, hottest
recorded session, games played, and largest CPU/GPU usage.

The game catalog lives in `hardwaremon_app/backend_fastapi/gaming/games.json`
so new games can be added without changing detector code. Game artwork is an
intentional placeholder in this release and is ready for future asset
integration.

---

## Distribution & Packaging

* Native Linux DEB packages
* Native Linux RPM packages
* APT repository support
* DNF repository support
* Windows installer support
* WinGet support
* Signed Android APKs with SHA-256 checksums
* GitHub Releases automation

Every release workflow publishes SHA-256 checksums, human-readable release
metadata, and GitHub artifact attestations. Desktop releases also publish a
CycloneDX SBOM for the Flutter and Python dependency sets they ship. See
[Verifying a HardwareMon release](docs/release-verification.md)
for beginner-friendly checksum, provenance, SBOM, and platform-signing guidance.

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
| Android         | ✅ Supported | Signed APK from GitHub Releases |

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

HardwareMon offers an Apple Silicon DMG from GitHub Releases. Core CPU and
memory monitoring works on real Mac hardware, while lower-level sensors remain
best-effort because macOS does not expose every value through simple public
APIs. HardwareMon reports unavailable data honestly rather than substituting
zeroes.

> Current macOS CI builds are consistently ad-hoc signed and are not yet
> Developer ID signed or notarized. After downloading, macOS may require
> **Right-click → Open** and confirmation on first launch.

| Area | Current macOS support |
|------|-----------------------|
| Dashboard | Working with capability-aware cards; unavailable sensors are omitted |
| CPU usage and name | Supported, including Apple M1/M2/M3/M4 names when reported |
| RAM used/available/total | Supported |
| Disk and network | Supported through the existing cross-platform collectors |
| MacBook battery | Supported when macOS reports a system battery |
| Temperatures, fans, and power | May be unavailable; never estimated or replaced with fake zero values |
| Processes | Viewing is experimental; termination is disabled on macOS |
| Historical monitoring | Supported for metrics macOS reports |
| Notifications | Supported subject to macOS notification permission |
| DMG launch | Supported on real Apple Silicon Mac hardware |
| Virtual machines | Not recommended unless the VM exposes a working Metal device |

Apple Silicon identifies hardware differently from Windows and Linux, process
control is more restricted, and several sensors need privileged/native
integrations that HardwareMon intentionally does not request today. Flutter
also requires Metal on macOS: a VM may boot macOS successfully yet show a blank
Flutter window when no Metal device is available. A real Mac is recommended for
release testing.

| Architecture | Support |
|--------------|---------|
| Apple Silicon (M1) | ✅ |
| Apple Silicon (M2) | ✅ |
| Apple Silicon (M3) | ✅ |
| Apple Silicon (M4) | ✅ |
| Intel (x86_64) | ❌ |

> Tested on Apple Silicon hardware. Intel Mac support is planned for a future release.

# Android

HardwareMon for Android is a native, standalone monitor for the phone or tablet it runs on. It starts collecting local telemetry as soon as it opens and does not require an account, server, or root access.

The dark Jetpack Compose dashboard provides:

* Live CPU usage when the device exposes it
* RAM usage with used, available, and total memory
* Internal storage usage with used, available, and total capacity
* Battery percentage, charging state, temperature, voltage, and health
* Wi-Fi or mobile connection state, local IP, and Wi-Fi link speed when available
* Android thermal-pressure status on supported versions
* Model, manufacturer, Android version, SDK level, device name, ABIs, and uptime
* Foreground-only live refreshes with clear unavailable states for restricted metrics
* Overview, Insights, and Watches areas with a persistent bottom navigation surface
* Five monitoring lenses that change health-score weighting without changing OS settings
* A rolling 60-sample session, session-drift analysis, and local snapshot journal
* Configurable CPU, memory, storage, battery, and thermal-pressure watches
* Native share-sheet export for live and saved session reports

Android limits access to some low-level hardware information. HardwareMon reports only values exposed by public platform APIs or readable system interfaces; it does not estimate hidden sensor values. CPU utilization, thermal details, Wi-Fi information, and some battery fields can therefore be unavailable on particular Android versions or manufacturer builds.

See [android/README.md](android/README.md) for architecture, build instructions, and a detailed API-limitations guide.


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

* Kotlin and Jetpack Compose
* Material 3-inspired HardwareMon dashboard
* State-driven ViewModel architecture
* Dedicated CPU, memory, storage, battery, network, thermal, and device collectors
* Foreground-aware refresh scheduling
* Permission-light, root-free local monitoring
* Responsive phone and tablet layouts

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

HardwareMon uses a dedicated GitHub Actions workflow for macOS release builds.
Tags matching `v*.*.*` build the Flutter app and bundled FastAPI helper on a
GitHub-hosted Mac, apply a final deep ad-hoc signature to the completed app,
validate all embedded frameworks, create and verify the DMG, and upload it to
the matching GitHub Release. Developer ID signing and notarization are deferred
until a real Apple Developer certificate is available. See the
[macOS release guide](hardwaremon_app/macos/README.md) for current behavior.

The existing GitHub Actions pipelines continue to handle:

* Linux DEB packaging
* Linux RPM packaging
* Windows installer generation
* WinGet publishing
* Signed Android APK packaging and verification
* Non-macOS GitHub Release assets
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

# Android Development

Open the `android/` directory as a standalone project in Android Studio, or use JDK 17 and an Android SDK from the command line:

```powershell
cd android
.\gradlew.bat testDebugUnitTest lintDebug assembleDebug
```

The APK is produced at `android/app/build/outputs/apk/debug/app-debug.apk` from the repository root. Full Android architecture and API-limit documentation lives in [android/README.md](android/README.md).

---

# Roadmap

Planned future improvements include:


* System tray integration
* Custom dashboard layouts
* Plugin architecture
* Detachable analytics windows
* Native macOS exploration

## Android

Planned improvements include:

* Home screen widgets
* Material You theming
* Optional notification delivery for foreground watch events
* Longer-term historical analytics beyond the current foreground session
* Wear OS support
* Quick Settings tile
* Battery-conscious background sampling

---

# Project Status

HardwareMon is under active development.

The project is evolving into a modern cross-platform monitoring platform focused on:

* performance
* desktop experience
* native Android monitoring
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
