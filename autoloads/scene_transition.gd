extends CanvasLayer
## Autoload singleton: a full-screen fade-to-black overlay that survives
## change_scene_to_file(), so a scene swap happens while the screen is
## still black instead of popping back to a bright frame mid-transition.
## Call fade_out() before changing scene and fade_in() after arriving.

const DEFAULT_FADE_SECONDS := 0.6

## Durees des deux phases de l'effet crt_off()/crt_on() : verticale d'abord
## (l'ecran s'ecrase en une ligne horizontale), puis horizontale (la ligne se
## resserre en un point) — comme l'extinction/l'allumage d'un vieux moniteur
## CRT. Utilise pour la transition boot systeme -> login (voir introduction.gd)
## plutot que le fade_out/fade_in generique ci-dessus.
const CRT_VERTICAL_SECONDS := 0.18
const CRT_HORIZONTAL_SECONDS := 0.12
## Demi-epaisseur (en fraction de l'ecran) de la ligne qui subsiste entre les
## rideaux haut/bas a la fin de la phase verticale.
const CRT_LINE_HALF_THICKNESS := 0.005

var _rect := ColorRect.new()
var _tween: Tween

## Les 4 "rideaux" noirs de l'effet CRT (crt_off/crt_on), un par bord — voir
## _reset_curtains(). Chacun grandit depuis son bord vers le centre via ses
## ancres plutot que via sa taille, pour rester correct quelle que soit la
## resolution.
var _curtain_top := ColorRect.new()
var _curtain_bottom := ColorRect.new()
var _curtain_left := ColorRect.new()
var _curtain_right := ColorRect.new()


func _ready() -> void:
	layer = 100
	_rect.color = Color.BLACK
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)

	for curtain in [_curtain_top, _curtain_bottom, _curtain_left, _curtain_right]:
		curtain.color = Color.BLACK
		curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		curtain.offset_left = 0.0
		curtain.offset_right = 0.0
		curtain.offset_top = 0.0
		curtain.offset_bottom = 0.0
		add_child(curtain)
	_reset_curtains()


## Fade the screen to black. Await this before change_scene_to_file().
func fade_out(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animate_to(1.0, fade_seconds)


## Fade the screen back in after arriving in the new scene.
func fade_in(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	await _animate_to(0.0, fade_seconds)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _animate_to(target_alpha: float, fade_seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", target_alpha, fade_seconds)
	await _tween.finished


## Effet "extinction CRT" : l'ecran se resserre en une ligne horizontale
## (rideaux haut/bas) puis en un point (rideaux gauche/droite), comme un
## vieux moniteur qu'on eteint. Alternative a fade_out() pour une fermeture
## plus "systeme" — la scene suivante se revele ensuite avec un fade_in()
## classique (voir handoff en fin de fonction). Await avant
## change_scene_to_file(), comme fade_out().
func crt_off() -> void:
	_set_curtains_mouse_filter(Control.MOUSE_FILTER_STOP)
	_reset_curtains()

	var line_edge := 0.5 - CRT_LINE_HALF_THICKNESS
	var tween_v := create_tween()
	tween_v.set_parallel(true)
	tween_v.tween_property(_curtain_top, "anchor_bottom", line_edge, CRT_VERTICAL_SECONDS)
	tween_v.tween_property(_curtain_bottom, "anchor_top", 1.0 - line_edge, CRT_VERTICAL_SECONDS)
	await tween_v.finished

	var tween_h := create_tween()
	tween_h.set_parallel(true)
	tween_h.tween_property(_curtain_left, "anchor_right", 0.5, CRT_HORIZONTAL_SECONDS)
	tween_h.tween_property(_curtain_right, "anchor_left", 0.5, CRT_HORIZONTAL_SECONDS)
	await tween_h.finished

	# Bascule vers le rect noir plein ecran utilise par fade_out()/fade_in() :
	# les rideaux se rouvrent instantanement pendant que le rect, deja opaque,
	# prend le relais — aucun des deux changements n'est visible. Permet
	# d'enchainer avec un fade_in() classique apres change_scene_to_file().
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.modulate.a = 1.0
	_reset_curtains()
	_set_curtains_mouse_filter(Control.MOUSE_FILTER_IGNORE)


## Remet les 4 rideaux a taille nulle contre leur bord (etat "ecran visible,
## rideaux ouverts") — appele a _ready() et au debut de chaque crt_off().
func _reset_curtains() -> void:
	_curtain_top.anchor_left = 0.0
	_curtain_top.anchor_right = 1.0
	_curtain_top.anchor_top = 0.0
	_curtain_top.anchor_bottom = 0.0

	_curtain_bottom.anchor_left = 0.0
	_curtain_bottom.anchor_right = 1.0
	_curtain_bottom.anchor_top = 1.0
	_curtain_bottom.anchor_bottom = 1.0

	_curtain_left.anchor_left = 0.0
	_curtain_left.anchor_right = 0.0
	_curtain_left.anchor_top = 0.0
	_curtain_left.anchor_bottom = 1.0

	_curtain_right.anchor_left = 1.0
	_curtain_right.anchor_right = 1.0
	_curtain_right.anchor_top = 0.0
	_curtain_right.anchor_bottom = 1.0


func _set_curtains_mouse_filter(filter: Control.MouseFilter) -> void:
	for curtain in [_curtain_top, _curtain_bottom, _curtain_left, _curtain_right]:
		curtain.mouse_filter = filter
