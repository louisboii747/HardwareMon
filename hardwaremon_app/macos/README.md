# HardwareMon macOS release notes

The macOS release is built as `HardwareMon.app`, with bundle identifier
`com.hardwaremon.HardwareMon`, then packaged in a signed and notarized DMG.

## Release credentials

A release uses paid Developer ID signing and notarization when all of these
GitHub Actions secrets are available:

- `MACOS_CERTIFICATE_BASE64` — Developer ID Application certificate exported as
  a base64-encoded PKCS#12 file
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_KEYCHAIN_PASSWORD`
- `MACOS_SIGNING_IDENTITY` — for example,
  `Developer ID Application: Example Company (TEAMID)`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

If this set is absent or incomplete, the workflow prints a warning, skips all
paid Apple signing/notarization steps, and continues with an ad-hoc-signed DMG.

## Unsigned developer artifacts

A workflow with no complete Apple credential set produces an ad-hoc-signed
developer DMG. Its app bundle is internally consistent and passes strict
`codesign` verification, but ad-hoc signing does not establish a trusted
developer identity or satisfy Gatekeeper for an internet-downloaded app.

Tag-triggered artifacts are still uploaded to the GitHub Release. After
deliberately verifying its source and checksum, a developer can remove the
quarantine attribute for local testing:

```bash
xattr -dr com.apple.quarantine /Applications/HardwareMon.app
```

Normal users should use the Developer ID-signed, notarized tag release and
should never need that command.
