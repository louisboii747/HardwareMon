# HardwareMon Gaming and overlay

HardwareMon Gaming 2.0 detects known game processes, records hardware sessions,
and presents a small always-on-top telemetry overlay on Windows, Linux, and
macOS. It does not inject code into games, hook renderers, or read game memory.

## Overlay controls

- `Ctrl + Shift + O`: show or hide the overlay globally.
- `Ctrl + Shift + I`: toggle interaction mode. The overlay is click-through by
  default, so it does not intercept game input.
- Use borderless or windowed mode. Exclusive fullscreen may cover normal OS
  windows.

The previous HardwareMon window size and position are restored when the overlay
closes. Overlay enablement and compact mode persist between launches.

## Real frame statistics

HardwareMon never estimates FPS from utilisation. A platform collector writes
an atomic JSON document and points the backend at it with
`HARDWAREMON_FRAME_STATS_PATH`:

```json
{"pid":1234,"fps":143.8,"frame_time_ms":6.95,"fps_1_percent_low":112.4,"provider":"presentmon"}
```

The bridge can be fed by PresentMon on Windows, MangoHud or a compositor-aware
collector on Linux, and a suitable macOS collector. Without a provider the UI
says `Provider unavailable`; hardware telemetry continues.

Android retains Gaming sessions and the live dashboard. HardwareMon does not
currently request Android's sensitive draw-over-other-apps permission, so a
system-wide Android overlay is reported as unsupported instead of silently
failing.

## Catalogue and artwork

`backend_fastapi/gaming/games.json` is the detection source of truth. Steam games
load their official Steam header image at runtime. Non-Steam games use a
deterministic local identity tile, keeping Gaming useful offline without
redistributing copyrighted artwork.
