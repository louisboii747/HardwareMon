# HardwareMon Plugin System

HardwareMon Plugin API v1 is an out-of-process extension platform. Plugin code
is never imported into Flutter or the FastAPI host. The backend broker owns
discovery, capability approval, lifecycle, authenticated IPC, health checks,
logs, crash recovery, installation and portable-aware persistence.

## Runtime architecture

```text
Flutter Plugin Studio
        |
        | loopback HTTP
        v
FastAPI plugin routes ---- plugin-registry.json
        |
        v
PluginBroker
  | capability filter
  | launch token
  | stdin/stdout JSON protocol
  +---- plugin process A
  +---- plugin process B
  +---- plugin process C
```

Each launch receives a random 256-bit-equivalent token. Messages without the
current token are rejected. Standard output is reserved for protocol messages;
standard error is captured as attributed plugin logs. Plugins receive a minimal
environment and their own directory as working directory.

This boundary prevents a plugin crash or dependency conflict from corrupting
the HardwareMon process. It is not a kernel security boundary: an executable
approved and launched by the user still has that user's operating-system
permissions. Capability grants control HardwareMon data and broker operations,
not arbitrary OS APIs. Only install plugins from publishers you trust.

## Lifecycle

1. Bundled plugins are copied into the active data directory on first run.
2. The broker validates every manifest, identifier, capability and entrypoint.
3. New plugins start disabled with no grants.
4. The user reviews and approves every requested capability in Plugin Studio.
5. Enabling launches a separate process and performs an authenticated hello.
6. The broker sends only data allowed by current grants.
7. Heartbeats update health. Thirty seconds without one marks a plugin
   unresponsive.
8. Unexpected exits are restarted with bounded backoff, at most five times.
9. Permission changes stop and disable the plugin before taking effect.

Registry writes use a temporary file followed by atomic replacement. Portable
mode naturally places the registry and installed plugins beneath
`HardwareMonData` alongside the portable database.

## Manifest

Every package contains one directory whose name matches its identifier and one
`hardwaremon-plugin.json`:

```json
{
  "api_version": 1,
  "id": "com.example.hardwaremon.my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "publisher": "Example",
  "description": "Explains exactly what the plugin does.",
  "homepage": "https://example.com",
  "entrypoint": { "type": "executable", "path": "my-plugin.exe" },
  "capabilities": ["telemetry.read", "network.connect"]
}
```

Identifiers use lowercase letters, numbers, dots, underscores and hyphens.
Entrypoints must remain inside the plugin directory. Supported entrypoints are
`executable` for release plugins and `python` for source/developer plugins.
Packaged HardwareMon can run bundled Python plugins through its isolated plugin
runner; third-party releases should ship a standalone executable.

## Capabilities

| Capability | Meaning |
| --- | --- |
| `telemetry.read` | Receive filtered live hardware samples |
| `inventory.read` | Read the hardware inventory through broker APIs |
| `history.read` | Read locally retained telemetry history |
| `events.publish` | Publish attributed events into HardwareMon |
| `network.listen` | Expose a local or LAN listening service |
| `network.connect` | Make outbound network connections |
| `settings.read` | Read explicitly shareable, non-secret settings |

Unknown capabilities invalidate a plugin. Grants must be a subset of requested
capabilities, and every requested capability must be approved before enabling.

## Protocol v1

Messages are UTF-8 JSON objects separated by newlines. Every message includes
`type` and `token`.

Host messages:

- `host.hello`: API version, plugin id and approved grants.
- `telemetry.sample`: capture timestamp and filtered telemetry payload.
- `host.shutdown`: request a clean process exit.

Plugin messages:

- `plugin.ready`: handshake completed.
- `plugin.heartbeat`: process remains responsive.
- `plugin.log`: attributed level and message.
- `plugin.event`: an event, accepted only with `events.publish`.

Protocol output must never be mixed with debugging prints. Use `plugin.log` or
standard error.

## Packaging and installation

HardwareMon packages use the `.hmp` extension and ZIP format. Build one with:

```powershell
py -3 hardwaremon_app/plugin_sdk/build_hmp.py path\to\com.example.plugin dist\example.hmp
```

Plugin Studio installs `.hmp` or `.zip` files through a staging directory. The
broker rejects absolute paths, parent traversal, symbolic links, multiple
manifests, more than 500 files, archives over 25 MB and expanded content over
100 MB. The staged manifest is validated before atomic activation.

Installed plugins can be removed only while disabled. Bundled official plugins
cannot be removed, though they remain disabled until explicitly approved.

## Python SDK

Copy `hardwaremon_app/plugin_sdk/python/hardwaremon_sdk.py` into a plugin:

```python
from hardwaremon_sdk import HardwareMonPlugin

plugin = HardwareMonPlugin()

def telemetry(message):
    payload = message["payload"]
    plugin.log(f"CPU usage is {payload.get('cpu_usage')}", "debug")

plugin.on("telemetry.sample", telemetry)
plugin.run()
```

The SDK validates launch environment, tracks grants, authenticates messages,
serializes writes and blocks event publication without the corresponding grant.

## Official plugins

- Prometheus Exporter exposes numeric approved telemetry at
  `http://127.0.0.1:9779/metrics`. It requests `telemetry.read` and
  `network.listen`.
- Developer Tools validates handshake, delivery and heartbeat behavior and
  periodically records sample counts. It requests `telemetry.read` and
  `events.publish`.

Both are installed disabled and require the same explicit permission approval
as third-party plugins.

## API

- `GET /plugins` — registry and health snapshot
- `GET /plugins/{id}` — details and bounded recent logs
- `POST /plugins/install` — staged base64 `.hmp` installation
- `PUT /plugins/{id}/grants` — replace approved capabilities and disable
- `PUT /plugins/{id}/enabled` — start or stop
- `POST /plugins/{id}/restart` — supervised restart
- `DELETE /plugins/{id}` — remove a disabled third-party plugin

The backend listens on loopback and remains owned by the HardwareMon desktop
process. These routes are not exposed by the separate LAN dashboard.
