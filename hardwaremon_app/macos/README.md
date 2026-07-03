# HardwareMon macOS releases

HardwareMon's macOS DMG is built by
`.github/workflows/macos_release.yml` on a GitHub-hosted macOS runner. The
Windows, Linux, Android, and website workflows are independent.

## Current release flow

The workflow runs manually through **Actions → macOS Release DMG → Run
workflow**, and automatically for tags matching `v*.*.*`.

It performs these operations in order:

1. Builds `HardwareMon.app` with Flutter in release mode and fails clearly if
   `build/macos/Build/Products/Release/HardwareMon.app` is absent.
2. Builds the FastAPI helper and embeds `HardwareMonBackend.app` inside the
   completed app bundle.
3. Removes extended-attribute detritus, then applies one consistent ad-hoc
   signature to the entire app with `codesign --force --deep --sign -`.
4. Immediately runs strict deep signature verification. Validation also checks
   every embedded Mach-O object and code-bearing bundle, including
   `local_notifier.framework`, while allowing unsigned resource-only bundles.
5. Smoke-launches the signed application.
6. Copies the already-signed app into the staging directory and verifies that
   copy before creating the DMG.
7. Creates the compressed DMG, mounts it, and revalidates the app inside it.
8. Uploads the DMG and SHA-256 checksum. Tag builds also publish them to the
   matching GitHub Release.

DMG creation cannot run if signing or verification fails. Nothing inside the
app bundle is changed after its final signature is applied.

## Ad-hoc signing status

Current CI builds are ad-hoc signed because the project does not yet have an
Apple Developer certificate. They do not require certificate secrets and are
not notarized. The ad-hoc signature is used to keep the app, plugin frameworks,
Flutter frameworks, and bundled telemetry helper under one internally
consistent code seal so macOS can load them.

An internet-downloaded build may still require **Control-click → Open** (or
**Right-click → Open**) and confirmation in macOS. If quarantine still blocks a
trusted, checksum-verified build during development, remove it from the copied
application with:

```bash
xattr -dr com.apple.quarantine /Applications/HardwareMon.app
```

Developer ID signing and notarization are intentionally deferred until a real
Apple Developer certificate is available. Do not add placeholder identities or
fake certificate secrets.

The release also publishes `SHA256SUMS-macos.txt`, CycloneDX SBOM and release
metadata JSON files, plus GitHub-hosted provenance and SBOM attestations. Follow
the repository's [release verification guide](../../docs/release-verification.md)
to verify a DMG before opening it.

## Testing a release

1. Run the workflow manually and confirm the log shows the expected app path,
   final ad-hoc signing, strict deep verification, and explicit
   `local_notifier.framework` verification.
2. Download the DMG artifact and verify its published SHA-256 checksum.
3. On an Apple Silicon Mac, mount the DMG and launch HardwareMon both directly
   and after copying it into `/Applications`.
4. Confirm the bundled telemetry backend starts and live metrics appear.

Use real Apple Silicon hardware for final UI testing. Flutter's macOS renderer
requires Metal, and virtual machines without a Metal-capable virtual GPU can
launch the process while showing a blank window. That is a VM graphics
limitation rather than evidence that the signed app bundle is invalid.

## Current macOS capability matrix

| Area | Status |
|------|--------|
| Dashboard | Working; capability-aware cards prioritise CPU and memory |
| CPU usage and Apple chip name | Supported |
| RAM used, available, and total | Supported |
| Disk and network | Supported through the existing cross-platform collectors |
| MacBook battery | Supported when macOS reports a system battery |
| Temperatures, fan RPM, and power draw | Limited or unavailable through public unprivileged APIs |
| Detailed GPU usage and VRAM | Limited; Apple unified memory is not presented as dedicated VRAM |
| Process list | Experimental and permission-dependent |
| Process termination | Disabled in the current macOS build |
| Historical monitoring | Supported for available metrics |
| Notifications | Subject to macOS notification permission |

HardwareMon does not require `sudo`, request invasive entitlements, or estimate
missing sensors. Diagnostics in Settings → About show the detected chip,
architecture, backend status, app-bundle location, capability flags, and a
reason for each unavailable metric.

Current release builds remain ad-hoc signed. Users may need to use
**Right-click → Open** after copying HardwareMon into `/Applications`.
Developer ID signing and notarization will be added only when a real Apple
Developer certificate is available.
