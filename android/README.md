# HardwareMon Companion (Android)

Native Android companion v0 for a HardwareMon desktop backend. It uses Kotlin,
Jetpack Compose, Material 3, Retrofit/Moshi, DataStore Preferences, and a small
MVVM-style state layer.

## Prerequisites

- JDK 17 or newer
- Android SDK with platform 36 and build tools installed
- `ANDROID_HOME` or `ANDROID_SDK_ROOT` configured (Android Studio is optional)
- A phone/emulator on the same network as the HardwareMon desktop

## Build from a terminal

From this `android/` directory:

```sh
./gradlew assembleDebug
```

On Windows PowerShell:

```powershell
.\gradlew.bat assembleDebug
```

The APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

To install it on a connected device with Android platform tools:

```sh
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Open the `android/` directory itself if you later use Android Studio. It is a
standalone Gradle project and does not depend on the Flutter desktop project.

## GitHub release workflow

The `Android Companion Release` workflow builds the app without Android Studio,
runs the debug unit tests, and uploads the resulting APK to a GitHub Release.

For a tag release, create and push a semantic version tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Tags matching `v*.*.*` trigger the workflow automatically. The uploaded asset
is named `HardwareMon-Companion-Android-debug-v0.1.0.apk` for that example.

To run it manually:

1. Open the repository's **Actions** tab on GitHub.
2. Select **Android Companion Release**.
3. Choose **Run workflow** and enter an existing release tag such as `v0.1.0`.

Companion v0 uploads a debug APK for testing. It is not production/release
signed; Gradle may apply its standard debug key so the APK can be installed on
test devices. No signing secrets or Android Studio installation are required.

TODO: add keystore-backed signing through GitHub Actions secrets and publish a
signed release APK and/or Android App Bundle (`.aab`) for production delivery.

## Test against a desktop

1. Start the HardwareMon backend and make it listen on a LAN-accessible address,
   not only `127.0.0.1`.
2. Allow its port through the desktop firewall for private/local networks.
3. Put the phone and desktop on the same network.
4. Enter the full base URL, for example `http://192.168.1.249:8384`.
5. Tap **Connect**. The app tests `GET /device/self`, then loads `GET /stats`.

The example IP is UI placeholder text only. It is not used as a default or sent
unless the user enters it.

## Expected backend responses

The identity endpoint should return at least one usable name. The preferred
shape is:

```json
{ "name": "Gaming PC" }
```

For compatibility, the app also accepts `device_name` or `hostname`, with
optional `platform`, `os`, and `version` fields. Unknown JSON fields are ignored.

The current desktop `/stats` contract is expected to resemble:

```json
{
  "cpu": 23,
  "cpu_temp": 61,
  "cpu_name": "Example CPU",
  "ram": 48,
  "ram_used": 15.3,
  "ram_total": 31.8,
  "gpu_usage": 37,
  "gpu_temp": 58,
  "gpu_name": "Example GPU"
}
```

All telemetry fields are nullable in the Android model. Optional Windows/Linux
sensor differences therefore do not fail the whole response. Missing or zero
temperature sensors and an unknown GPU are omitted from the dashboard.

## Local HTTP note

Companion v0 permits cleartext HTTP because local HardwareMon backends commonly
use a direct LAN URL. `INTERNET` permission and an explicit network security
configuration are included. This is appropriate for local development, but a
future authenticated or remote-access version should use HTTPS and revisit the
cleartext policy.
