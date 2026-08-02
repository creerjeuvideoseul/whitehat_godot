class_name Palette
## Single source of truth for the game's colors and font-size scale.
## Values are the ones already dominant across the existing scenes (not a
## redesign) — this file exists to stop new/edited scenes from picking
## slightly-different one-off shades, which had already started happening
## (near-white text alone had 3 different values before this file existed).
##
## Usable directly from any script (e.g. `Palette.TEXT_NORMAL`, no preload
## needed — `class_name` makes it a global identifier). .tscn files can't
## reference a GDScript const directly; for those, pick the matching Theme
## Type Variation on the node instead (see themes/main_theme.tres) — kept in
## sync with these same values by hand, since only a handful of roles exist.

# --- Colors -----------------------------------------------------------

## Default body/label text.
const TEXT_NORMAL := Color(0.92, 0.96, 0.94, 1.0)

## Destructive / danger text (matches the existing "Quitter" buttons).
const TEXT_DANGER := Color(1.0, 0.36, 0.36, 1.0)

## Panel/button borders, focus rings, status indicators — "the interface green".
const BORDER_ACCENT := Color(0.22, 0.87, 0.45, 1.0)

## Titles and emphasized text (panel headers, primary action labels) —
## brighter than BORDER_ACCENT on purpose; a distinct role, not a duplicate.
const TEXT_ACCENT := Color(0.24, 1.0, 0.5, 1.0)

## Locked/disabled UI (e.g. "Continuer" before any save exists).
const TEXT_LOCKED := Color(0.4, 0.45, 0.42, 1.0)

## Secondary system-monitor gauge fill (e.g. desktop MEM meter). CPU-style
## gauges reuse BORDER_ACCENT directly rather than an alias — this is the
## only gauge color that didn't already exist somewhere in the project.
const GAUGE_MEM := Color(1.0, 0.65, 0.15, 1.0)

# --- Font sizes ---------------------------------------------------------
# Named scale, reused as-is rather than picking new one-off sizes per screen.

const SIZE_SMALL := 20
const SIZE_BODY := 22
const SIZE_SUBTITLE := 26
const SIZE_LARGE := 30
const SIZE_TITLE := 32
const SIZE_MENU_ITEM := 38
const SIZE_HERO := 48
