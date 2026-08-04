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

## App window background (dark green) — distinguishes an open window from
## the near-black desktop behind it.
const WINDOW_BG := Color(0.03, 0.1, 0.07, 0.98)

## App window title bar / sidebar background — lighter than WINDOW_BG for
## contrast, still readably distinct from the near-white BUBBLE colors.
const WINDOW_HEADER_BG := Color(0.07, 0.18, 0.13, 1.0)

## Chat bubble background for the other party (interlocutor).
const BUBBLE_OTHER := Color(0.1, 0.16, 0.14, 1.0)

## Chat bubble background for the player's own messages.
const BUBBLE_PLAYER := Color(0.086, 0.302, 0.176, 0.9)

## Alternate bubble tint (blue) — lets one contact's messages read as
## distinct from another's inside the same chat window (e.g. Jean Ranoud
## vs. AnonGhost's default BUBBLE_OTHER green-neutral).
const BUBBLE_BLUE := Color(0.1, 0.15, 0.28, 1.0)

## Plain "system/console" text — connection status, terminal-style asides —
## as opposed to an actual chat bubble from a contact.
const CONSOLE_TEXT := Color(0.55, 0.63, 0.58, 1.0)

## Bright info-blue text — same role as TEXT_ACCENT (emphasis on a dark
## background) but blue, for distinguishing one speaker's name from the
## default green (e.g. Gilles de la Touret in the intro cutscene, vs. BUBBLE_BLUE which
## is a background tint rather than a readable foreground color).
const TEXT_BLUE_ACCENT := Color(0.4, 0.7, 1.0, 1.0)

## Solid "breaking news" red fill — the intro's TV-broadcast overlay badges
## (EN DIRECT / Flash info, see introduction.tscn). Distinct from TEXT_DANGER,
## which is a pale red meant as *text* on a dark background, not a bold
## solid fill of its own.
const ALERT_RED_BG := Color(0.78, 0.09, 0.09, 1.0)

# --- Font sizes ---------------------------------------------------------
# Named scale, reused as-is rather than picking new one-off sizes per screen.

const SIZE_SMALL := 20
const SIZE_BODY := 22
const SIZE_SUBTITLE := 26
## Référence du projet pour le corps de texte "mis en avant" (2026-08-04) —
## la taille du DialogueLabel de l'intro (dialogue_balloon.tscn) est celle à
## laquelle tout le reste doit s'aligner par défaut : bandeaux/incrustations,
## messages d'avertissement, etc. Ne s'en écarter que si un élément a une
## contrainte de place physique qui l'exige (ex. un petit badge).
const SIZE_LARGE := 30
const SIZE_TITLE := 32
const SIZE_MENU_ITEM := 38
const SIZE_HERO := 48
