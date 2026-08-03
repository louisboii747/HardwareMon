# HardwareMon Privacy Policy

_Last updated: 3 August 2026_

## Overview

HardwareMon is designed with privacy as a core principle.

The application performs hardware monitoring, system diagnostics, and benchmarking entirely on your device. As of the date above, HardwareMon does **not** upload hardware information, telemetry, benchmark results, or diagnostic data to the developer or any HardwareMon-operated servers.

## Information Processed

To provide its functionality, HardwareMon may process the following information locally on your device:

- CPU information
- GPU information
- Memory information
- Storage information
- Operating system information
- Live hardware telemetry
- Network statistics
- Running process information
- Benchmark results
- Application settings

All of this information is processed locally and remains on your device unless you explicitly choose to share it.

## Local Storage

HardwareMon stores certain data locally to provide its features, including:

- Application settings
- Historical telemetry (if enabled)
- Benchmark history
- User-generated diagnostic reports
- Plugin manifests, approvals, and local plugin logs

These files are stored only on your device. Settings reset intentionally preserves the privacy-notice acknowledgement; locally stored reports, history, and plugin data are not silently deleted by that action. They can be removed through supported in-app controls where provided, or by uninstalling HardwareMon and deleting its per-user application-data directory.

## Internet Connectivity

Some HardwareMon features require an internet connection, including:

- Checking for application updates
- Downloading new releases when requested by the user
- Weather lookups, when the weather summary is enabled
- GitHub Device Flow authentication and GitHub issue submission, when requested by the user

The companion dashboard communicates over the local network. HardwareMon does not provide a HardwareMon-operated relay or cloud tunnel for that feature.

## GitHub issue reporting and diagnostic exports

HardwareMon can authenticate to GitHub using GitHub's Device Authorization Flow. The resulting OAuth token is stored using the operating system's protected credential storage; it is not stored in application settings or diagnostic exports.

Before creating an issue, HardwareMon displays the exact Markdown issue body for review. Only that reviewed text is submitted. Optional textual diagnostics are sanitized and size-limited. GitHub Issues does not offer a general API for uploading arbitrary binary attachments, so locally exported ZIP files and screenshots remain on the device unless the user separately uploads them through GitHub.

HardwareMon does not embed a personal access token, OAuth client secret, device code, or user credential in its application binaries.

These connections are used solely for their intended purpose and are not used to collect hardware telemetry or benchmark data.

## Future Online Features

HardwareMon may introduce optional online services in future releases, such as anonymous benchmark comparison or cloud-based features.

If these features are added:

- Participation will always be optional.
- HardwareMon will request your explicit consent before transmitting any benchmark data.
- This Privacy Policy will be updated to clearly explain what information is collected, how it is used, and why it is needed.

At the time of this revision, HardwareMon does **not** upload benchmark results or hardware telemetry.

## Information Not Intended for Collection

If anonymous benchmark sharing is introduced in the future, HardwareMon is intended **not** to collect or transmit personal information such as:

- Usernames
- Personal files or documents
- Lists of installed applications
- Device serial numbers
- MAC addresses
- Personally identifiable information (PII)

Like any online service, your IP address may be processed by standard internet infrastructure when communicating with online services, but it is not intended to be collected as part of benchmark data.

## Open Source

HardwareMon is open source. Its source code is publicly available, allowing anyone to inspect how the application handles data and verify its privacy practices.

## Changes to This Policy

This Privacy Policy may be updated as HardwareMon evolves. Any significant changes to how information is processed or shared will be reflected in future revisions of this document.

## Contact

If you have any questions about this Privacy Policy or how HardwareMon handles data, please open an issue on the GitHub repository or contact the project maintainer.

Email: **louishinchliffe11@gmail.com**
