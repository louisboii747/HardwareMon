# Verifying a HardwareMon release

HardwareMon release pages publish the application package together with
evidence that helps you confirm what you downloaded and where it came from.
Verification is optional, but recommended when installing outside an operating
system package manager.

## 1. Verify the SHA-256 checksum

Download the package and the matching `SHA256SUMS-*.txt` file from the same
GitHub Release. Keep them in one directory.

On macOS or Linux:

```bash
shasum -a 256 -c SHA256SUMS-macos.txt
sha256sum -c SHA256SUMS-linux.txt
```

Use the checksum file matching your platform. A successful check prints `OK`.
On Windows PowerShell, compare the generated hash with the line in
`SHA256SUMS-windows.txt`:

```powershell
Get-FileHash .\HardwareMon-*.exe -Algorithm SHA256
Get-Content .\SHA256SUMS-windows.txt
```

If the values differ, do not run the file. Delete it and download it again from
the official HardwareMon GitHub Release.

## 2. Verify GitHub build provenance

Tagged release artifacts receive a GitHub artifact attestation from the exact
workflow run that built them. Install the GitHub CLI, authenticate it, then run:

```bash
gh attestation verify HardwareMon-macOS-v1.2.3.dmg --repo LouisHinchliffe/HardwareMon
```

Replace the filename with the EXE, DEB, RPM, Flatpak, DMG, or APK you downloaded.
A successful result binds the file's digest to this repository and its GitHub
Actions build identity. It does not replace platform code signing or a checksum;
the three controls answer different questions.

## 3. Read the SBOM

Files ending in `.cdx.json` are CycloneDX software bills of materials. They list
the locked Dart packages and declared Python dependencies used by the build.
They are useful for auditing dependencies and responding to a newly disclosed
vulnerability; they are not executable and do not need to be installed.

The matching `release-metadata-*.json` records the source commit, workflow run,
artifact size, and SHA-256 digest in a human-readable form. GitHub also stores a
signed SBOM attestation for the release artifact.

## Current signing status

| Platform | Current trust mechanism |
|----------|-------------------------|
| Windows | Installer packaging, SHA-256, SBOM, and GitHub provenance attestation |
| macOS | Whole-bundle ad-hoc signature, SHA-256, SBOM, and GitHub provenance attestation |
| Linux DEB/APT | Signed APT repository metadata plus release evidence |
| Linux RPM/DNF | GPG-signed RPM/repository metadata plus release evidence |
| Flatpak | SHA-256, SBOM, and GitHub provenance attestation |
| Android | Project signing key, APK signature verification, SHA-256, release metadata, and GitHub provenance attestation |

macOS builds are not yet Developer ID signed or notarized. After verifying the
checksum, users may need to copy HardwareMon into `/Applications`, then use
**Right-click → Open** on first launch. Developer ID signing and notarization
will be added only when a real Apple Developer certificate is available.
