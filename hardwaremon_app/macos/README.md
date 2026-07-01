# HardwareMon macOS releases

HardwareMon's macOS DMG is built by
`.github/workflows/macos_release.yml` on a GitHub-hosted macOS runner. Windows,
Linux, Android, and website workflows are independent and are not used or
modified by the macOS release job.

## Release flow

The workflow runs manually through **Actions → macOS Release DMG → Run
workflow**, and automatically for tags matching `v*.*.*`.

It performs the following operations in order:

1. Builds `HardwareMon.app` with Flutter in release mode.
2. Builds the FastAPI backend using `backend_fastapi/backend_macos.spec`.
3. Copies the resulting `HardwareMonBackend.app` into `Contents/Helpers` and
   creates the stable executable entrypoint `Contents/Helpers/backend`.
4. Signs every nested Mach-O binary, dylib, framework, and helper bundle before
   applying the final hardened-runtime signature to `HardwareMon.app`.
5. Verifies the app's structure, executable permissions, linked libraries,
   icon, bundle identifiers, nested signatures, and Gatekeeper assessment.
6. Notarizes and staples the app when notarization is enabled.
7. Copies the immutable app with `ditto`, adds the `/Applications` symlink, and
   creates the compressed DMG.
8. Signs, notarizes, staples, verifies, mounts, and revalidates the final DMG.
9. Uploads the DMG and SHA-256 checksum as workflow artifacts. Tag builds also
   create or update the matching GitHub Release.

Nothing is injected into or rewritten inside the app after its final signing
pass. Apple's stapler is the only later operation that touches the app bundle.

## Required GitHub Actions secrets

Configure these under **Repository settings → Secrets and variables → Actions**:

- `MACOS_CERTIFICATE_BASE64` — Developer ID Application certificate and private
  key exported as a base64-encoded `.p12` file.
- `MACOS_CERTIFICATE_PASSWORD` — password used when exporting the `.p12`.
- `MACOS_KEYCHAIN_PASSWORD` — strong temporary password chosen for the Actions
  keychain; it does not need to match an existing Mac login password.
- `MACOS_SIGNING_IDENTITY` — full certificate identity, for example
  `Developer ID Application: Example Company (TEAMID)`.
- `APPLE_ID` — Apple ID used by `notarytool`.
- `APPLE_APP_SPECIFIC_PASSWORD` — app-specific password generated for that
  Apple ID.
- `APPLE_TEAM_ID` — ten-character Apple Developer team identifier.

Secret values are never printed. The certificate is imported only for signed
builds into an ephemeral keychain under `$RUNNER_TEMP`, which is removed in an
`always()` cleanup step.

Encode the certificate on macOS with:

```bash
base64 -i developer-id-application.p12 | pbcopy
```

Or on Windows PowerShell:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("developer-id-application.p12")
) | Set-Clipboard
```

## Tag releases versus manual builds

Public tag builds are strict. A `v*.*.*` tag fails near the start of the job if
any required signing or notarization secret is missing, and the log lists the
missing secret names. A public DMG is therefore never accidentally published
with an ad-hoc signature or without notarization.

Manual `workflow_dispatch` builds are more flexible:

- With all Developer ID secrets, the app and DMG are Developer ID signed.
- With all Apple credentials as well, the app and DMG are notarized and stapled.
- Without complete signing secrets, the bundle is re-signed ad hoc after the
  backend is embedded. It still passes strict code-seal validation, but it does
  not establish a trusted developer identity and is intended only for testing.

An internet-downloaded ad-hoc build will not satisfy Gatekeeper. After checking
its workflow origin and SHA-256 checksum, a developer may remove quarantine for
local testing:

```bash
xattr -dr com.apple.quarantine /Applications/HardwareMon.app
```

Normal users should only receive the signed and notarized tag release.

## Testing the next release

1. Run the workflow manually first. Download the DMG artifact and confirm it
   mounts, shows the HardwareMon icon, launches on Apple Silicon, and connects
   to its bundled telemetry backend.
2. Confirm all seven secrets above are present.
3. Create and push the next semantic version tag:

   ```bash
   git tag v18.0.1
   git push origin v18.0.1
   ```

4. In the Actions log, confirm the Developer ID identity, strict `codesign`
   verification, app and DMG notarization acceptance, successful stapler
   validation, `hdiutil verify`, mount/detach validation, and launch smoke test.
5. Download `HardwareMon-macOS-18.0.1.dmg` from the matching GitHub Release on a
   real Mac. Test launching directly from the mounted DMG and after copying the
   app into `/Applications`.
