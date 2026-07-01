# HardwareMon macOS releases

The macOS release is built as `HardwareMon.app`, with bundle identifier
`com.hardwaremon.HardwareMon`, then packaged as a validated DMG. Codemagic is
the release builder for macOS; the existing GitHub Actions workflows continue
to own Windows, Linux, Android, and website releases.

## Release flow

The root [`codemagic.yaml`](../../codemagic.yaml) defines one macOS-only
workflow. It can be started manually from the Codemagic UI for testing and runs
automatically when a Git tag beginning with `v` is pushed.

The workflow:

1. Builds the Flutter release app on an Apple Silicon Codemagic machine.
2. Builds the FastAPI backend with `backend_macos.spec` and embeds the resulting
   `HardwareMonBackend.app` under `HardwareMon.app/Contents/Helpers`.
3. Signs every Mach-O object and nested framework before signing the outer app.
4. Verifies the bundle, linked libraries, executable permissions, and code seal.
5. Notarizes and staples the app when Apple credentials are configured.
6. Builds, optionally signs/notarizes, mounts, and verifies the final DMG.
7. Retains the DMG and checksum as Codemagic artifacts. Tag builds also upload
   them to the GitHub Release matching `CM_TAG`; manual builds never publish.

Add the repository to Codemagic and create its webhook so `tag` events reach
the workflow. Manual builds are available through **Start new build** even
though ordinary branch pushes are deliberately not configured as triggers.

The historical `.github/workflows/macos_release.yml` file is intentionally
unchanged. After the Codemagic tag build has been verified, disable that legacy
workflow from the GitHub Actions UI if it is still enabled; otherwise both CI
providers will respond to the same macOS release tag.

## Release credentials

Create these environment-variable groups in the Codemagic application or team
settings. Mark every credential as **Secret**.

### `macos_credentials`

- `MACOS_SIGNING_MODE` — non-secret mode selector. Use `auto` to sign whenever
  a certificate exists, `adhoc` to force a developer build, or `developer-id`
  to require signing. Add this variable even when no Apple secrets are used so
  the `macos_credentials` group exists for unsigned builds.
- `CM_CERTIFICATE` — optional base64-encoded Developer ID Application `.p12`.
  When absent, Codemagic produces an internally valid ad-hoc-signed build.
- `CM_CERTIFICATE_PASSWORD` — optional password for `CM_CERTIFICATE`; omit it
  when the `.p12` has no password.
- `APPLE_ID` — Apple ID used by `notarytool`.
- `APPLE_APP_SPECIFIC_PASSWORD` — app-specific password for that Apple ID.
- `APPLE_TEAM_ID` — ten-character Apple Developer team identifier.

The three Apple notarization variables are optional as a set. Notarization is
enabled only when all three and `CM_CERTIFICATE` are available.

Encode a certificate on macOS with:

```bash
base64 -i developer-id-application.p12 | pbcopy
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("developer-id-application.p12")
) | Set-Clipboard
```

### `github_credentials`

- `GITHUB_TOKEN` — required for tag publishing. Use a fine-grained GitHub PAT
  scoped to this repository with **Contents: Read and write**, or an equivalent
  classic token with repository write access.

Codemagic imports both groups through the `environment.groups` section. Do not
place secret values directly in `codemagic.yaml`.

## Signing behavior

A release uses Developer ID signing whenever `CM_CERTIFICATE` is available.
The signing identity is discovered from the temporary Codemagic keychain, so a
separate identity-name variable is not required.

If notarization credentials are absent or incomplete, the workflow prints a
warning and skips notarization without breaking manual test builds.

## Unsigned developer artifacts

A workflow without `CM_CERTIFICATE` produces an ad-hoc-signed developer DMG.
Its app bundle is internally consistent and passes strict `codesign`
verification, but ad-hoc signing does not establish a trusted developer
identity or satisfy Gatekeeper for an internet-downloaded app.

After deliberately verifying its source and checksum, a developer can remove
the quarantine attribute from an unsigned test build for local testing:

```bash
xattr -dr com.apple.quarantine /Applications/HardwareMon.app
```

Normal users should use the Developer ID-signed, notarized tag release and
should never need that command.
