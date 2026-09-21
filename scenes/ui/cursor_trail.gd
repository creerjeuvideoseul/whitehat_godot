extends Control
class_name CursorTrailOverlay
## Legere trainee fantome derriere le curseur reel (qui reste visible et
## parfaitement precis pour le clic) — voir autoloads/screen_effects.gd qui
## l'instancie par-dessus tout le jeu. Purement decoratif (mouse_filter =
## IGNORE, aucune donnee persistee) : retirer cette instance suffit a annuler
## l'effet sans toucher au reste de ScreenEffects (shader d'ecran compris).

const TRAIL_POINT_COUNT := 5
const TRAIL_RADIUS := 3.0
## Plus petit = la trainee "colle" plus a la souris ; garde discret pour ne
## jamais donner l'impression d'un retard au clic (le curseur reel n'est lui-
## meme jamais touche).
const TRAIL_LERP_WEIGHT := 0.3

var _trail_positions: Array[Vector2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var start: Vector2 = get_viewport().get_mouse_position()
	for i in TRAIL_POINT_COUNT:
		_trail_positions.append(start)


func _process(_delta: float) -> void:
	var target: Vector2 = get_viewport().get_mouse_position()
	for i in _trail_positions.size():
		_trail_positions[i] = _trail_positions[i].lerp(target, TRAIL_LERP_WEIGHT)
		target = _trail_positions[i]
	queue_redraw()


func _draw() -> void:
	for i in _trail_positions.size():
		var fade: float = 1.0 - float(i + 1) / float(_trail_positions.size() + 1)
		draw_circle(_trail_positions[i], TRAIL_RADIUS * fade, Color(Palette.BORDER_ACCENT, fade * 0.3))
