extends Control
class_name HelpBubble
## Bulle d'aide contextuelle générique : cadre jaune vif (Palette.ALERT_YELLOW,
## même identité visuelle que ClueBoardTooltip), flèche dessinée à la main qui
## pointe HORIZONTALEMENT (contrairement à ClueBoardTooltip, qui pointe vers le
## HAUT) — pour une bulle posée à côté d'un élément d'écran plutôt qu'au-dessus.
## Les deux sens sont supportés (voir point_at(..., arrow_on_left)) : flèche à
## gauche/boîte à droite de l'élément pointé, ou l'inverse. Ni le texte ni la
## position ne sont fixés dans cette scène (voir set_text()/point_at()) : un
## futur appelant n'a qu'à instancier, appeler les deux, puis écouter `closed`.
##
## Hauteur dynamique : la largeur seule est fixe (BOX_WIDTH) ; la hauteur se
## recalcule à partir de la taille minimale réelle du contenu (texte +
## bouton, voir _resize_to_content) à chaque appel de point_at(), pour qu'un
## texte plus long ou plus court n'ait jamais besoin d'un réglage à la main.

const BOX_WIDTH := 420.0
## Largeur de la flèche = l'écart exact demandé entre la bordure de l'élément
## pointé et la bulle (voir point_at) : la flèche comble tout cet espace.
const ARROW_WIDTH := 20.0
const ARROW_HALF_HEIGHT := 14.0
const FADE_IN_SECONDS := 0.3

signal closed

@onready var _box: Panel = %Box
@onready var _margin: MarginContainer = %Margin
@onready var _message_label: Label = %MessageLabel
@onready var _close_button: Button = %CloseButton

## Voir point_at() — mémorisé pour que _resize_to_content()/_draw() (rejoués
## à chaque appel) sachent toujours de quel côté placer flèche/boîte.
var _arrow_on_left: bool = true


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	# Invisible jusqu'au premier point_at() : évite un flash à la mauvaise
	# position/taille le temps que _resize_to_content() attende sa frame
	# (même raison que ClueBoardTooltip).
	modulate.a = 0.0


## Clé ui.csv du message à afficher — à appeler avant point_at(), qui a
## besoin du texte déjà en place pour calculer la hauteur du contenu.
func set_text(translation_key: String) -> void:
	_message_label.text = tr(translation_key)


## Recalcule la hauteur puis positionne la bulle pour que la pointe de la
## flèche touche exactement `target_global_pos` — la boîte se centre
## verticalement sur ce point ("au même niveau" que l'élément pointé).
## `arrow_on_left` (défaut) : flèche à gauche, boîte s'étend vers la droite —
## pour une bulle posée à droite de l'élément pointé. false : inverse, flèche
## à droite, boîte vers la gauche — pour une bulle posée à sa gauche. Termine
## par un fondu d'apparition.
func point_at(target_global_pos: Vector2, arrow_on_left: bool = true) -> void:
	_arrow_on_left = arrow_on_left
	await _resize_to_content()
	var x := target_global_pos.x if arrow_on_left else target_global_pos.x - size.x
	global_position = Vector2(x, target_global_pos.y - size.y * 0.5)
	_fade_in()


## `_margin` a déjà sa largeur définitive (BOX_WIDTH, fixée dès la scène) dès
## la première frame — seule sa hauteur minimale (texte replié + bouton +
## padding) n'est fiable qu'une fois le nœud réellement passé par une passe
## de layout. Deux frames d'attente, même recette que ClueBoardTooltip.
func _resize_to_content() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var box_height: float = _margin.get_combined_minimum_size().y
	_box.position = Vector2(ARROW_WIDTH if _arrow_on_left else 0.0, 0.0)
	_box.size = Vector2(BOX_WIDTH, box_height)
	size = Vector2(ARROW_WIDTH + BOX_WIDTH, box_height)
	queue_redraw()


func _fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	closed.emit()


## Petit triangle plein pointant horizontalement : base contre la boîte,
## pointe touchant target_global_pos (voir point_at) — même technique de
## dessin à la main que ClueBoardTooltip._draw(). Coordonnées locales du sens
## flèche-à-gauche vs flèche-à-droite tout simplement inversées (x -> total
## width - x), la boîte et la flèche échangeant juste leurs bords.
func _draw() -> void:
	var center_y := size.y * 0.5
	var arrow_base_x := ARROW_WIDTH if _arrow_on_left else BOX_WIDTH
	var arrow_tip_x := 0.0 if _arrow_on_left else size.x
	var points := PackedVector2Array([
		Vector2(arrow_base_x, center_y - ARROW_HALF_HEIGHT),
		Vector2(arrow_base_x, center_y + ARROW_HALF_HEIGHT),
		Vector2(arrow_tip_x, center_y),
	])
	draw_colored_polygon(points, Palette.ALERT_YELLOW)
