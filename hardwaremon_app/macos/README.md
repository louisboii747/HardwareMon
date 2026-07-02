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
   every embedded Mach-O object and bundle, including
   `local_notifier.framework`.
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

## Testing a release

1. Run the workflow manually and confirm the log shows the expected app path,
   final ad-hoc signing, strict deep verification, and explicit
   `local_notifier.framework` verification.
2. Download the DMG artifact and verify its published SHA-256 checksum.
3. On an Apple Silicon Mac, mount the DMG and launch HardwareMon both directly
   and after copying it into `/Applications`.
4. Confirm the bundled telemetry backend starts and live metrics appear.
