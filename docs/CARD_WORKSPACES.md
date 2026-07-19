# Card workspaces

HardwareMon card workspaces let each user decide which analytics deserve space.
Configuration is local, profile-like and independent for every page surface.

## Using card edit mode

Select **Arrange cards** above a configurable card surface.

- Long-press and drag a card onto another card to reorder it.
- Select **Resize card** to cycle through Compact, Standard, Wide and Large.
- Select **Remove card** to remove it from the active surface. Removal is
  reversible through the hidden-card menu.
- Use the hidden-card menu to restore individual cards.
- **Reset page** restores default order, visibility and sizes for that surface.

Keyboard users can focus the edit actions, resize and hide controls normally.
Cards themselves remain non-interactive while edit mode is active so dragging
cannot accidentally open analytics or trigger actions.

Responsive sizing is span-based. Wide and Large cards occupy two columns when
space permits and safely collapse to one column in compact windows.

## Saved layouts

**Saved layouts** captures every configured page at once, including:

- Card order
- Hidden cards
- Card size
- Page-specific configurations

Layouts can be named, applied or deleted. The same manager is available from
every workspace toolbar and through Ctrl+K by searching for “Saved Card
Layouts”. Suggested uses include Minimal, Gaming, Diagnostics and Presentation.

## Persistence and migration

Workspace state is stored in SharedPreferences under schema-versioned keys.
Cards are addressed by stable page and card identifiers rather than list
positions. When a release introduces a new card, it is appended visibly without
discarding the user's existing configuration. Removed cards are ignored safely.

The workspace engine currently applies to card-based analytics on Dashboard,
Performance, Gaming, Network, Storage, Reliability, Benchmark, Companion Centre
and Plugin Studio. Purpose-built non-card surfaces such as process tables,
settings forms and history lists retain their native layouts.
