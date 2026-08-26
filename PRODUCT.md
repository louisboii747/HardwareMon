# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

HardwareMon serves people who want to understand what their computer or Android device is doing while they work, play games, diagnose slowdowns, or establish a performance baseline. Desktop users include PC enthusiasts, gamers, developers, and everyday users who need readable system information without learning specialist monitoring tools. This audience and usage context are inferred from the shipped feature set, documentation, and the requested redesign.

## Product Purpose

HardwareMon collects real-time hardware telemetry, turns it into readable system health and performance views, and keeps history, sessions, watches, and benchmark results on the user's device. A successful session lets someone spot pressure, inspect the cause, save useful evidence, and take an available action without leaving the app.

## Positioning

HardwareMon combines live cross-platform telemetry with local, telemetry-derived guidance and practical desktop workflows. It reports unavailable sensors as unavailable instead of inventing values, and it keeps core monitoring useful without an account or cloud service.

## Operating Context

On desktop, people keep HardwareMon open beside games and demanding applications, move between overview and focused analytics, manage processes, inspect storage and network activity, run benchmarks, review reliability and maintenance guidance, and use tray commands or keyboard shortcuts. Android users monitor the device in their hand through a native interface. The desktop app must remain usable at compact and maximized window sizes.

## Capabilities and Constraints

- Preserve all shipped desktop destinations and workflows: Dashboard, Processes, Performance, Gaming, Network, Storage, Maintenance, Reliability, Benchmark, Customization, Settings, Companion, Plugins, bug reporting, focused analytics, Telemetry Studio, the command palette, card workspaces, session journal, update flows, privacy notice, tray integration, keyboard shortcuts, and the gaming overlay.
- Preserve the Flutter service, model, persistence, backend, and dependency-injection boundaries that power those workflows.
- Keep Windows, Linux, and macOS desktop behavior capability-aware. HardwareMon must label missing metrics honestly.
- Keep native Android behavior and visual implementation outside this desktop replacement unless a shared product fact requires alignment.
- Respect reduced-motion and disabled-animation preferences. Controls must remain keyboard and screen-reader accessible.
- The requested redesign replaces the current desktop visual identity while retaining every function. The user has asked for subtle, charming animation and a result that reads as human-designed rather than generated from dashboard conventions.

## Brand Commitments

Keep the HardwareMon name, local-first privacy promise, technically honest tone, and recognizable hardware-monitoring purpose. The desktop interface may replace the existing glass, glow, cyan-heavy cards, oversized radii, and floating showcase treatment. Avoid promotional language inside operational screens.

## Evidence on Hand

The repository contains the production Flutter desktop UI under `hardwaremon_app/lib/windows_ui`, the native Android UI under `android/app/src/main`, product documentation in `README.md`, platform limitations, tests for the major desktop surfaces, and the HardwareMon logo asset at `hardwaremon_app/assets/hardwaremon.png`. No user research, external brand manual, or licensed illustration set is present, so future work must not fabricate them.

## Product Principles

- Show the reading first, then the explanation and action.
- Keep monitoring truthful when a platform withholds a sensor.
- Make dense technical information calm enough to scan during real work.
- Keep core monitoring local and useful without an account.
- Preserve expert shortcuts while giving new users clear labels and safe actions.

## Accessibility & Inclusion

The desktop interface must support keyboard navigation, visible focus, semantic labels, legible contrast, compact windows, text scaling, and reduced motion. Status cannot rely on color alone.
