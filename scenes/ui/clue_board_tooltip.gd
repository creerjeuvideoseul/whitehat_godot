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

signal closed

@onready var _box: Panel = %Box
@onready var _margin: MarginContainer = %Margin
@onready var _message_label: Label = %MessageLabel
@onready var _close_button: Button = %CloseButton


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
	_message_label.text = tr(translation_key)


## Recalcule la hauteur puis positionne la bulle pour que la pointe de la
## flèche touche exactement `target_global_pos` — la boîte se centre
## horizontalement sous ce point. Termine par un fondu d'apparition.
func point_at(target_global_pos: Vector2) -> void:
	await _resize_to_content()
	global_position = Vector2(target_global_pos.x - BOX_WIDTH * 0.5, target_global_pos.y)
	_fade_in()


## `_margin` a déjà sa largeur définitive (BOX_WIDTH, fixée dès la scène) dès
## la première frame — seule sa hauteur minimale (texte replié + bouton +
## padding) n'est fiable qu'une fois le nœud réellement passé par une passe
## de layout, d'où l'attente d'une frame (même recette que ClueBoard.setup()
## avant de lire une taille calculée).
func _resize_to_content() -> void:
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
	var center_x := BOX_WIDTH * 0.5
	var points := PackedVector2Array([
		Vector2(center_x - ARROW_HALF_WIDTH, ARROW_HEIGHT),
		Vector2(center_x + ARROW_HALF_WIDTH, ARROW_HEIGHT),
		Vector2(center_x, 0.0),
	])
	draw_colored_polygon(points, Palette.ALERT_YELLOW)
