# HardwareMon for Android

HardwareMon for Android is a standalone, native device monitor. It reads the
phone or tablet it is running on and does not connect to the HardwareMon
desktop app, FastAPI backend, another computer, or any remote telemetry stream.
No configuration is required: launch the app and its dashboard starts collecting
local telemetry.

## Dashboard

The Jetpack Compose dashboard reports:

- device-wide CPU usage when Android permits `/proc/stat` access;
- RAM usage, used/available memory, and total memory;
- internal data-storage usage, used space, available space, and total space;
- battery percentage, charging state, temperature, voltage, and reported health;
- device name, model, manufacturer, Android release, SDK level, ABIs, and uptime;
- active network transport, local IP address, and Wi-Fi link speed when exposed;
- Android thermal pressure status on Android 10 (API 29) and newer.

Values refresh every three seconds while the app is in the foreground. The
monitor stops refreshing when the app is backgrounded. A manual refresh button
is also available in the dashboard header.

## Architecture

This is a standalone Gradle project under `android/`, written in Kotlin with a
state-driven Jetpack Compose UI. Platform reads are separated into collectors:

```text
app/src/main/java/com/hardwaremon/android/
├── data/
│   ├── TelemetryRepository.kt
│   └── collectors/
│       ├── CpuStatsCollector.kt
│       ├── MemoryStatsCollector.kt
│       ├── StorageStatsCollector.kt
│       ├── BatteryStatsCollector.kt
│       ├── NetworkStatsCollector.kt
│       ├── ThermalStatsCollector.kt
│       └── DeviceInfoCollector.kt
├── model/TelemetryModels.kt
├── ui/
└── viewmodel/DashboardViewModel.kt
```

`DashboardViewModel` owns the foreground refresh loop and exposes immutable UI
state. `TelemetryRepository` coordinates collectors off the main thread. The
app requests only network-state and Wi-Fi-state access; it does not request the
`INTERNET` permission and contains no HTTP client.

## Build and run

Requirements:

- JDK 17 or newer
- Android SDK platform 36 and its build tools
- `ANDROID_HOME` or `ANDROID_SDK_ROOT` configured

Open the `android/` directory as its own project in Android Studio, or build it
from a terminal.

Windows PowerShell:

```powershell
cd android
.\gradlew.bat testDebugUnitTest lintDebug assembleDebug
```

macOS/Linux:

```sh
cd android
./gradlew testDebugUnitTest lintDebug assembleDebug
```

The debug APK is written to:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

Install it on a connected device or emulator with:

```sh
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

The repository's `Android Release` GitHub Actions workflow runs unit tests and
release lint, injects the tag-derived version, builds and signs a release APK,
verifies its certificate, and publishes both
`HardwareMon-Android-<tag>.apk` and its SHA-256 checksum. Maintainers configure
the signing material through `ANDROID_SIGNING_KEY_BASE64`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_PASSWORD`
repository secrets.

## Android API limitations

HardwareMon reports only values the OS actually exposes. It shows
**Unavailable** instead of estimating or inventing restricted metrics.

- Android has no public, universal API for whole-device CPU utilization.
  HardwareMon samples Linux `/proc/stat` where readable. Some recent devices or
  vendor builds restrict that file, so CPU usage may remain unavailable without
  root. The app does not request root or substitute its own process usage.
- Public thermal APIs expose a throttling/pressure category, not CPU, GPU, or
  SoC sensor temperatures. Thermal status is unavailable before API 29. Battery
  temperature is a separate value supplied by the battery service.
- RAM "free" is Android's available memory (`ActivityManager.availMem`), which
  includes memory the OS can reclaim. Android deliberately uses free RAM for
  caches, so this is more useful than a raw unused-page count.
- Storage figures describe the internal data filesystem visible to the app.
  Adoptable storage, removable media, reserved blocks, and manufacturer system
  partitions can make Settings report a different aggregate capacity.
- Wi-Fi link speed is the negotiated link value reported by Android, not an
  internet speed test. It and the local IP can be absent on some devices,
  transports, VPNs, restricted profiles, or vendor implementations.
- Battery health, voltage, and temperature depend on data supplied by the
  device's battery driver and may be unavailable or coarsely reported.

These limitations are intentional: the app stays permission-light, does not
require root, and never claims access to metrics Android withheld.
