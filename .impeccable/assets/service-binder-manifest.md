# Service Binder asset manifest

Sources: approved comp `.impeccable/mocks/service-binder-work-sheet.png`, its approved prompt, `PRODUCT.md`, the shell surface brief, current Flutter typography/icon usage, and the existing chart dependency.

## Decision

**No new raster asset is required for the Service Binder desktop shell.** The approved composition is an implementation reference, not an image to composite into the app. All text must remain crisp, selectable semantic Flutter text; live values and charts must remain data-driven.

| Visual ingredient | Ship as | Raster? |
| --- | --- | --- |
| `HardwareMon` and page titles | Live Flutter `Text`; condensed workhorse sans for titles | No |
| Controls, labels, prose | Live Flutter `Text`; neutral system/workhorse sans | No |
| Measurements, timestamps, axes | Live Flutter `Text`; tabular mono with tabular figures | No |
| Font delivery | Licensed `.ttf`/`.otf` files bundled through Flutter, or verified platform fonts; never text baked into images | No raster |
| Graphite frame, off-white/charcoal sheet, blue-gray rail | Theme tokens, `Container`, `DecoratedBox`, and layout widgets | No |
| Traveling selected index tab | Flutter geometry and animation; rectangular tab with 2 px selection marker | No |
| Sheet rules, seams, grid lines, red evidence brackets | Borders and small `CustomPainter`s | No |
| Navigation, toolbar, state, and hardware glyphs | Existing Material `Icons`/Material Symbols with semantic labels; native window caption glyphs where applicable | No |
| CPU and memory gauges, storage bar, focus/pressed states | Flutter layout and `CustomPainter`; values remain live | No |
| Main telemetry history and mini sparklines | Existing chart implementation/`fl_chart` fed by real telemetry | No |
| Condition stamp/check and OK/warning/error register | Semantic widgets plus icons, labels, and evidence-driven color | No |
| Window controls, dropdowns, buttons, search/commands, pause/refresh/settings | Semantic Flutter/native controls with keyboard and screen-reader behavior | No |
| Crossfade, short slide, tab travel, chart interpolation | Flutter animation honoring reduced-motion and disabled-animation settings | No |
| Paper grain, pencil marks, handwritten labels, laminate photo texture | Omit; explicitly rejected by the approved prompt and surface brief | No asset |
| Decorative binder holes/eyelets shown in the comp | Omit; explicitly excluded by the surface brief and unnecessary to the task | No asset |

## Existing raster asset

`hardwaremon_app/assets/hardwaremon.png` remains available for existing application identity/icon uses. It is not needed inside this shell composition: the comp presents the product name as live type, and stretching the square logo into page chrome would reduce fidelity and accessibility.

## Generation queue

None. Do not generate a background, texture, chart screenshot, gauge image, icon sheet, wordmark, or rasterized text. If the implementation later exposes a truly image-led empty state or branded illustration outside this approved shell, assess that surface separately rather than importing it into this manifest.
