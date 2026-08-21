extends Control
class_name ClueBoardTooltip
## Bulle d'aide contextuelle générique : cadre jaune vif (Palette.ALERT_YELLOW,
## plutôt que le vert habituel des fenêtres du bureau — signale "un conseil",
## pas du contenu de jeu), flèche dessinée à la main qui pointe vers un point
## précis de l'écran, bouton "Fermer". Ni le texte ni la position ne sont fixés
## dans cette scène (voir set_text()/point_at()) : un futur écran n'a qu'à
## instancier, appeler les deux, puis écouter `closed` — voir desktop.gd,
## _maybe_show_clue_board_tooltip pour le premier exemple d'utilisation
## (bulle "recherche darkweb" de la fenêtre Collecte d'indices).
##
## Hauteur dynamique : la largeur seule est fixe (BOX_WIDTH) ; la hauteur se
## recalcule à partir de la taille minimale réelle du contenu (texte +
## bouton, voir _resize_to_content) à chaque appel de point_at(), pour qu'un
## texte plus long ou plus court n'ait jamais besoin d'un réglage à la main.

const BOX_WIDTH := 800.0
const ARROW_HEIGHT := 54.0
const ARROW_HALF_WIDTH := 14.0
const FADE_IN_SECONDS := 0.3
## Distance minimale entre le bord gauche de l'écran et celui de la boîte —
## un point_at() proche du bord gauche (ex. champ de recherche du header)
## centrerait sinon la boîte au point de la flèche à en dépasser hors écran.
const MIN_LEFT_MARGIN := 20.0

signal closed

@onready var _box: Panel = %Box
@onready var _margin: MarginContainer = %Margin
@onready var _message_label: RichTextLabel = %MessageLabel
@onready var _close_button: Button = %CloseButton

## Position locale (en x) de la pointe de la flèche — normalement
## BOX_WIDTH * 0.5 (boîte centrée sur la flèche), mais décalée si point_at()
## a dû recaler la boîte contre MIN_LEFT_MARGIN : la flèche, elle, reste
## exactement sur target_global_pos, seule la boîte se déplace.
var _arrow_local_x: float = BOX_WIDTH * 0.5


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	# Invisible jusqu'au premier point_at() : évite un flash à la mauvaise
	# position/taille le temps que _resize_to_content() attende sa frame
	# (même raison que le hide-puis-reveal des fenêtres du bureau, voir
	# clue_board_window.gd::_reveal_once_settled).
	modulate.a = 0.0


## Clé ui.csv du message à afficher — à appeler avant point_at(), qui a
## besoin du texte déjà en place pour calculer la hauteur du contenu.
func set_text(translation_key: String) -> void:
	## html_to_bbcode : même pseudo-HTML que les données mail/SMS/OSINT (voir
	## rich_text_markup.gd) pour <color=important> — ce texte vient de ui.csv,
	## pas d'un fichier .dialogue, donc pas de resolve_dialogue_colors ici
	## (pas de clue_id, rien à rendre cliquable).
	_message_label.text = RichTextMarkup.html_to_bbcode(tr(translation_key))


## Recalcule la hauteur puis positionne la bulle pour que la pointe de la
## flèche touche exactement `target_global_pos` — la boîte se centre
## horizontalement sous ce point, sauf si ça la ferait déborder à gauche de
## l'écran (voir MIN_LEFT_MARGIN) : elle est alors recalée contre cette marge,
## la flèche restant elle sur `target_global_pos` (voir _arrow_local_x/_draw).
## Termine par un fondu d'apparition.
func point_at(target_global_pos: Vector2) -> void:
	await _resize_to_content()
	var box_x := maxf(target_global_pos.x - BOX_WIDTH * 0.5, MIN_LEFT_MARGIN)
	global_position = Vector2(box_x, target_global_pos.y)
	_arrow_local_x = target_global_pos.x - box_x
	queue_redraw()
	_fade_in()


## `_margin` a déjà sa largeur définitive (BOX_WIDTH, fixée dès la scène) dès
## la première frame — seule sa hauteur minimale (texte replié + bouton +
## padding) n'est fiable qu'une fois le nœud réellement passé par une passe
## de layout. Deux frames d'attente, comme _reveal_once_settled dans
## clue_board_window.gd : une pour que Layout termine sa passe de mise en
## page, une seconde par marge de sécurité.
func _resize_to_content() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var box_height: float = _margin.get_combined_minimum_size().y
	_box.position = Vector2(0.0, ARROW_HEIGHT)
	_box.size = Vector2(BOX_WIDTH, box_height)
	size = Vector2(BOX_WIDTH, ARROW_HEIGHT + box_height)
	queue_redraw()


func _fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	closed.emit()


## Petit triangle plein pointant vers le haut : base contre le haut de la
## boîte (y = ARROW_HEIGHT), pointe touchant target_global_pos (y = 0, voir
## point_at) — même technique de dessin à la main que ClueBoard._draw() pour
## ses traits de connexion, plutôt qu'un asset dédié.
func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(_arrow_local_x - ARROW_HALF_WIDTH, ARROW_HEIGHT),
		Vector2(_arrow_local_x + ARROW_HALF_WIDTH, ARROW_HEIGHT),
		Vector2(_arrow_local_x, 0.0),
	])
	draw_colored_polygon(points, Palette.ALERT_YELLOW)
