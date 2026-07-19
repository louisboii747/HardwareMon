# HardwareMon VNext companion subsystems

HardwareMon's companion features stay local-first. The desktop application is
the authority for live telemetry, the FastAPI process supplies read-only
hardware evidence, and no feature requires an account or cloud service.

## Gaming sessions

The existing gaming detector watches the local process list and matches known
game executables from `backend_fastapi/gaming/games.json`. It starts and closes
sessions automatically, persists aggregate CPU/GPU/RAM/temperature/power data,
and records notable events. Samples are versioned so FPS can be added as a new
optional metric without changing session identity or history APIs.

## Maintenance Centre

Maintenance recommendations are evidence-based and read-only. Long uptime,
storage pressure, startup load, thermals, BIOS identity and battery evidence are
reported when the operating system exposes them. Missing facts remain visibly
unavailable. Driver, backup and restore-point checks use provider slots and must
not claim a healthy state until a platform provider exists.

## Companion Centre

The Companion Centre contains four bounded subsystems:

- Snapshot Studio renders Compact, Standard, Social and Minimal cards through a
  Flutter repaint boundary and writes a real PNG. Branding and accent colour are
  user-controlled.
- Hardware Inventory reads the `/inventory` contract and exports print-friendly
  PDF, JSON or TXT. Empty device categories are preserved for future providers.
- Export Centre builds a schema-versioned JSON bundle from the exact categories
  selected by the user. It never silently includes unselected information.
- Runtime & Extensions reports portable storage identity, plugin manifests and
  native widget-host availability.

## LAN dashboard and QR pairing

The web dashboard binds an ephemeral port on IPv4 interfaces only after the user
starts it. Every request requires a high-entropy pairing token, including live
telemetry polling. The QR code contains the LAN URL and token. Multiple viewers
are supported by Dart's asynchronous HTTP server and are listed by remote IP.
Stopping the dashboard closes all listeners and clears connection state.

The operating-system firewall may still require permission for inbound LAN
traffic. HardwareMon does not open firewall rules automatically.

## Portable mode

Portable mode is explicitly enabled by either `HARDWAREMON_PORTABLE=1` or a
`portable.flag` file beside the executable. Its data root is
`HardwareMonData` beside the executable. Installed mode continues to use the
platform application-support directory. Packaging must route the backend
database and SharedPreferences storage through the reported root before portable
mode can be advertised as fully self-contained in a release.

## Plugin platform

The manifest foundation is now backed by a real out-of-process broker,
capability approval, lifecycle supervision, authenticated newline-JSON IPC,
health reporting, bounded logs, crash recovery, staged `.hmp` installation and
portable-aware persistence. See `docs/PLUGIN_SYSTEM.md` for the complete API,
security model, SDK and packaging workflow.

## Desktop widgets

Widget types and presentation controls belong in the companion capability
model. Always-on-top, click-through and per-pixel transparency require native
multi-window hosts on Windows and Linux. The UI reports that platform gate
honestly until those runners are packaged and tested; it does not simulate a
floating widget inside the main window.

## Global search and theming

Ctrl+K is the universal entry point. VNext pages and features contribute actions
and keywords to the existing command palette. Customization Studio remains the
theme editor and profile store: it owns live preview, accent/surface/sidebar,
blur, glow, shadow, radius, import/export and reset behavior rather than
duplicating theme state in the Companion Centre.
