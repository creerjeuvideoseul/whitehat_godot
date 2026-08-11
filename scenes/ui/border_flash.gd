extends Panel
class_name BorderFlash
## Bordure d'accroche visuelle (fondu, pas de coupure nette) pour attirer
## l'œil sur un élément qui vient d'apparaître — ex: le téléphone d'Alizée
## une fois révélé (voir desktop.gd). Générique et réutilisable : s'ajoute
## comme enfant en plein cadre de n'importe quel Control cible (mêmes
## ancres pleines que BorderOverlay dans chat_window.tscn), joue seule puis
## se libère — rien à gérer côté appelant, même logique que PlayerThought.

const WIDTH := 10
const DURATION_SECONDS := 0.5

@export var color: Color = Color.WHITE
## À ajuster si la cible a des coins arrondis (ex: une fenêtre) — 0 convient
## à un cadre rectangulaire comme le téléphone.
@export var corner_radius: int = 0


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = WIDTH
	style.border_width_top = WIDTH
	style.border_width_right = WIDTH
	style.border_width_bottom = WIDTH
	style.border_color = color
	style.set_corner_radius_all(corner_radius)
	add_theme_stylebox_override("panel", style)

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, DURATION_SECONDS / 2.0)
	tween.tween_property(self, "modulate:a", 0.0, DURATION_SECONDS / 2.0)
	await tween.finished
	queue_free()
