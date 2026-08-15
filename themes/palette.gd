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
## vs. RelayGhost's default BUBBLE_OTHER green-neutral).
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

## Jaune vif, même rôle qu'ALERT_RED_BG (remplissage plein, pas du texte) —
## palier intermédiaire du dégradé blanc → jaune → rouge des jauges CPU/MEM.
const ALERT_YELLOW := Color(1.0, 0.84, 0.0, 1.0)

## Vert foncé discret — pour un texte "code/syntaxe" en petit, qui ne doit
## pas concurrencer TEXT_ACCENT/BORDER_ACCENT (ex. la légende technique en
## bas du téléphone d'Alizée).
const TEXT_GREEN_DIM := Color(0.14, 0.42, 0.24, 1.0)

## Mise en évidence des passages "indice" dans un texte brut (mail/SMS) — la
## balise <color=indice> des données (voir RichTextMarkup.html_to_bbcode)
## pointe ici plutôt que sur un hex écrit en dur dans chaque fichier JSON, pour
## ne changer la teinte qu'à un seul endroit.
const TEXT_HIGHLIGHT := Color(1.0, 0.596, 0.0, 1.0)

## Variante de TEXT_HIGHLIGHT pour un fond clair (bulles SMS pastel de
## certains contacts, voir SmsConversation.color_background) — même teinte,
## assombrie sans désaturer pour rester "orange foncé", pas "marron" (voir
## is_light() pour savoir laquelle des deux utiliser selon le fond).
const TEXT_HIGHLIGHT_ON_LIGHT := Color(0.879, 0.393, 0.038, 1.0)

## Mise en évidence des mots "importants" dans les dialogues (intro, chat) et
## les données brutes (mail/SMS) — la balise [color=important] des fichiers
## .dialogue (voir RichTextMarkup.resolve_important_color) et <color=important>
## des données JSON (voir RichTextMarkup.html_to_bbcode) pointent ici plutôt
## que sur un hex écrit en dur dans chaque fichier, pour ne changer la teinte
## qu'à un seul endroit. Sans rapport avec TEXT_HIGHLIGHT (indices) ni
## TEXT_DANGER (rouge pâle réservé au texte d'avertissement) : un rouge vif,
## dédié.
const TEXT_IMPORTANT := Color(1.0, 0.401, 0.295, 1.0)

## Variante de TEXT_IMPORTANT pour un fond clair (bulles SMS pastel de
## certains contacts, voir SmsConversation.color_background) — même teinte,
## assombrie sans désaturer, même recette que TEXT_HIGHLIGHT_ON_LIGHT (voir
## is_light() pour savoir laquelle des deux utiliser selon le fond). Seul
## resolve_important_color() (dialogues, toujours sur fond sombre) n'a pas
## besoin de cette variante — voir html_to_bbcode() pour <color=important>.
const TEXT_IMPORTANT_ON_LIGHT := Color(0.644, 0.081, 0.158, 1.0)

## Bordure des panneaux d'indices "de résolution" (catégories FIN/FINSECONDAIRE
## du tableau d'enquête, voir ClueBoard._apply_panel_state) une fois débloqués —
## même bleu que ImportantButton (voir themes/main_theme.tres), pour rappeler
## visuellement que ce sont ces indices-là qui débloquent le bouton "Générer
## le rapport".
const CLUE_SOLUTION_BORDER := Color(0.25, 0.55, 0.95, 1.0)
## Fond des mêmes panneaux — même rapport d'assombrissement/désaturation que
## le fond vert habituel d'un indice débloqué (Color(0.09, 0.24, 0.16, 1.0))
## par rapport à BORDER_ACCENT, mais décliné en bleu.
const CLUE_SOLUTION_BG := Color(0.09, 0.16, 0.28, 1.0)

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

# --- Helpers -------------------------------------------------------------

## Vrai si `color` est visuellement claire (luminance perçue, pondération
## ITU-R BT.601) — pour choisir entre une variante de couleur pensée pour un
## fond sombre et une pensée pour un fond clair (ex. TEXT_HIGHLIGHT vs
## TEXT_HIGHLIGHT_ON_LIGHT selon le fond d'une bulle SMS). Seuil 0.6 choisi
## empiriquement : au-dessus, un texte/accent sombre reste lisible dessus.
static func is_light(color: Color) -> bool:
	var luminance := 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	return luminance > 0.6
