# HardwareMon GitHub bug reporting

## User workflow

Open **Settings > Help & Support > Report a Bug** or choose **Report a Bug**
from the command palette. Drafting, diagnostic collection, preview, ZIP export,
and pending-report storage work without GitHub authentication.

Before submission, HardwareMon shows the exact bounded and redacted Markdown
body that will be sent. Choose **Send Report**, connect GitHub if required,
authorize the device code in the system browser, and return to HardwareMon. A
successful response displays the issue number, URL, report ID, and actions to
open or copy the issue and open the local attachment folder.

GitHub's Issues REST API cannot attach arbitrary local binary files. The ZIP and
screenshots remain local. Use **Open GitHub issue** and attach them manually.
HardwareMon never implies that a local path is visible to repository maintainers.

Failed reports remain under Pending Reports and can be viewed, retried, or
deleted. Sign-out deletes the OAuth token from protected credential storage.

## Repository-owner OAuth setup

1. Open GitHub **Settings > Developer settings > OAuth Apps > New OAuth App**.
2. Use an application name such as `HardwareMon Bug Reporter`.
3. Enter the HardwareMon project URL as the homepage URL.
4. Enter a valid project URL for the authorization callback URL. Device Flow
   does not redirect to it, but GitHub requires the field.
5. Create the OAuth App, then enable **Device Flow** in its settings.
6. Copy the OAuth **Client ID**. Do not generate, distribute, or embed the client
   secret.
7. Confirm Issues are enabled for `louisboii747/HardwareMon`. Optional labels
   such as `bug`, `crash`, `telemetry`, and `platform-windows` may be created;
   HardwareMon submits only labels that already exist.
8. Build with:

   ```powershell
   flutter build windows --release `
     --dart-define=HARDWAREMON_GITHUB_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID `
     --dart-define=HARDWAREMON_GITHUB_OWNER=louisboii747 `
     --dart-define=HARDWAREMON_GITHUB_REPO=HardwareMon
   ```

Use the equivalent `--dart-define` values in Linux, macOS, and Android CI build
jobs. A harmless public Client ID may be used for compile validation. Never add
a token or OAuth client secret to source, build definitions, logs, or artifacts.

If the Client ID is absent, local reporting remains available. Debug builds
show the missing define; release builds show that GitHub reporting is not
configured.

## Security and storage

Device Flow requests `public_repo`, the narrow GitHub OAuth scope that permits
an ordinary user to create an issue in a public repository. HardwareMon never
collects a GitHub password and never embeds a PAT, owner token, private key, or
OAuth client secret.

`flutter_secure_storage` stores only the access token:

- Windows: protected Windows credential storage.
- macOS: Keychain.
- Android: Keystore-backed encrypted storage.
- Linux: Secret Service through libsecret. Linux packages require
  `libsecret-1-0`; development requires `libsecret-1-dev`. If no Secret Service
  is available, authentication fails visibly and no plaintext fallback is used.

Users can revoke the OAuth App from GitHub's **Applications** settings. A `401`
response causes HardwareMon to delete the revoked credential. Tokens are never
stored in SharedPreferences, report JSON, ZIP files, logs, screenshots, issue
bodies, or pending-report metadata.

Before preview, export, or submission, HardwareMon redacts authorization values,
GitHub token shapes, secret-like fields, home/user paths, email addresses,
public IP addresses, MAC addresses, SIDs, serials, hostnames, and known secret
environment values. Diagnostics are bounded before issue creation.

## Troubleshooting

- **Reporting not configured:** rebuild with `HARDWAREMON_GITHUB_CLIENT_ID`.
- **Device code expired:** choose Retry and authorize the new code.
- **Access denied:** begin sign-in again and approve the request.
- **Repository unavailable:** verify owner/name, repository visibility, and
  Issues settings.
- **Token revoked:** sign in again; HardwareMon removes the invalid token.
- **Linux secure storage unavailable:** install libsecret and run a Secret
  Service such as GNOME Keyring or KDE Wallet.
- **Rate limited:** wait until the time reported by GitHub and retry the pending
  report.
- **Issue exists but attachment is local:** open the issue and add the files
  manually from the attachment folder.
