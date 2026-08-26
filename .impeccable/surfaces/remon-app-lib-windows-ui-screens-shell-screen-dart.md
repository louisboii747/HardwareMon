---
version: 1
slug: "remon-app-lib-windows-ui-screens-shell-screen-dart"
primary_target: "hardwaremon_app/lib/windows_ui/screens/shell_screen.dart"
related_targets: ["hardwaremon_app/lib/windows_ui/core/theme/app_theme.dart","hardwaremon_app/lib/windows_ui/core/theme/app_colors.dart","hardwaremon_app/lib/windows_ui/widgets/glass_panel.dart","hardwaremon_app/lib/windows_ui/widgets/metric_card.dart"]
---

# HardwareMon desktop shell replacement

## Scope and mode

- Surface: Flutter desktop shell and every screen rendered inside it.
- Mode: Operate.
- Primary task: read live system state, move to a focused tool, and act without losing context.

## Audience, job, and constraints

- Desktop users monitor a machine during ordinary work, gaming, or diagnosis.
- Keep all existing destinations, actions, keyboard shortcuts, command-palette entries, drill-downs, workspaces, services, persistence, overlays, privacy notices, and update flows.
- Keep compact and maximized window layouts usable. Respect reduced motion and the existing animation setting.
- The finished app uses crisp type. No handwriting font, pencil font, paper sketch, torn tape, binder holes, glass, glow, floating card grid, or decorative fake readings.

## Chosen direction

- World: Service Binder.
- Approved composition: `.impeccable/mocks/service-binder-work-sheet.png`.
- Memorable moment: the selected section travels as a blue index tab while one continuous work sheet crossfades to the next real tool.
- Typography: condensed workhorse sans for titles, neutral system sans for controls and prose, tabular mono for measurements.
- Motion: tab marker travel, restrained page fade/short slide, chart interpolation, and status-stamp changes. No hover lift or ambient pulse.

## Implementation grammar

- Corners: 0 px for sheets and rails; 4 to 6 px for controls; 8 px maximum for modal surfaces.
- Rules: 1 px cool-gray or blue-gray separators; 2 px selected index marker; red brackets only for warning or error evidence.
- Elevation: no floating page shadows. One grounded frame shadow may separate the app from the OS window.
- Type ramp: 30 px page title, 20 px section title, 14 px control/body, 12 px labels, 11 px metadata; tabular measurements use 18 to 38 px according to hierarchy.
- Density: 8 px base spacing; 16 to 20 px sheet insets; adjacent information shares ruled regions instead of separate cards.
- Light/dark: warm off-white work sheet is the primary light appearance. Dark appearance uses charcoal work sheets with blue-gray rules while retaining the binder grammar.

## Visible ingredient inventory

| Ingredient | Commitment | Medium |
| --- | --- | --- |
| App frame | graphite outer frame and blue-gray section index | semantic Flutter layout and theme tokens |
| Navigation | labeled destinations with familiar icons and a traveling rectangular tab | Flutter widgets and Material Symbols |
| Utility strip | current page, telemetry state, search/commands, refresh, pause, display options | semantic Flutter controls |
| Work sheet | one continuous surface per page with ruled content regions | Flutter containers and borders |
| Rules and seams | fine blue-gray lines that establish hierarchy | borders and small custom painters |
| Typography | crisp condensed headings, system labels, tabular readings | Flutter text styles; never raster text |
| Live chart | dominant real telemetry history with existing preferences | existing telemetry chart code |
| Condition register | real system state, explicit label, red bracket only when evidence warrants it | Flutter widgets and semantics |
| Hardware register | real GPU, storage, network, and watch information when available | existing models and page widgets |
| Material texture | omitted because the user rejected sketch and handwriting treatment | accepted omission |
| Primary actions | direct labeled controls with focus rules and pressed inset | semantic Flutter buttons |

## Unresolved decisions

- None for the desktop replacement. Native Android keeps its current Material implementation.
