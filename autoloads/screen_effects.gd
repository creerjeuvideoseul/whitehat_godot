extends CanvasLayer
## Autoload singleton : habillage visuel "on regarde un ecran physique",
## par-dessus toutes les scenes (menu, bureau, dialogues...) mais sous
## SceneTransition (layer 100) pour que le fondu au noir des changements de
## scene reste un vrai noir, sans grain visible dessus.
##
## Deux effets independants poses ici, tous les deux purement decoratifs
## (mouse_filter = IGNORE partout, aucun impact sur les clics existants) :
## - un shader plein ecran (scanlines/vignette/flicker/glitch rare, voir
##   assets/shaders/screen_grain.gdshader) ;
## - une legere trainee derriere le curseur reel (voir CursorTrailOverlay,
##   scenes/ui/cursor_trail.gd) — le curseur systeme reste visible et precis,
##   seule une trainee fantome le suit.
##
## Rollback rapide : retirer la ligne ScreenEffects de project.godot
## ([autoload]) desactive tout l'effet d'un coup, sans toucher au reste du jeu.

const LAYER := 90
const GRAIN_SHADER := preload("res://assets/shaders/screen_grain.gdshader")

## Durée et intensité du sursaut de glitch déclenché par pulse_glitch() ci-
## dessous — nettement au-dessus des valeurs par défaut du shader (glitch rare
## et discret en temps normal), pour marquer un instant narratif précis sans
## pour autant être un effet nouveau à concevoir (mêmes uniformes que le
## grain permanent, juste poussés temporairement).
const GLITCH_PULSE_SECONDS := 0.35
const GLITCH_PULSE_CHANCE := 0.6
const GLITCH_PULSE_INTENSITY := 0.35

## Fondu d'entrée/sortie du grain (voir set_grain_enabled) — coupure nette
## auparavant (retour joueur : tranchait avec le reste du jeu, entièrement
## animé en douceur).
const GRAIN_FADE_SECONDS := 0.6

var _grain_rect := ColorRect.new()
var _grain_material := ShaderMaterial.new()
var _grain_fade_tween: Tween


func _ready() -> void:
	layer = LAYER

	_grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_material.shader = GRAIN_SHADER
	_grain_rect.material = _grain_material
	add_child(_grain_rect)

	add_child(CursorTrailOverlay.new())


## Coupe/rétablit uniquement le grain d'écran (scanlines/vignette/flicker) —
## la trainée de curseur n'est pas concernée. Utilisé par GallerySection : les
## scanlines rendaient les vraies photos "rayées", pas seulement l'interface
## (voir gallery_section.gd), donc l'effet se désactive tant qu'une galerie
## (grille ou détail d'une publication, superposé par-dessus) est affichée.
## Fondu plutôt qu'une coupure nette (voir GRAIN_FADE_SECONDS) : `visible`
## n'est basculé qu'aux extrémités (true avant de monter, false une fois
## descendu à zéro) pour ne pas laisser un ColorRect invisible mais toujours
## dessiné une fois le fondu de sortie terminé.
func set_grain_enabled(enabled: bool) -> void:
	if is_instance_valid(_grain_fade_tween):
		_grain_fade_tween.kill()

	if enabled:
		_grain_rect.visible = true
		_grain_fade_tween = create_tween()
		_grain_fade_tween.tween_property(_grain_rect, "modulate:a", 1.0, GRAIN_FADE_SECONDS)
	else:
		_grain_fade_tween = create_tween()
		_grain_fade_tween.tween_property(_grain_rect, "modulate:a", 0.0, GRAIN_FADE_SECONDS)
		_grain_fade_tween.tween_callback(func() -> void: _grain_rect.visible = false)


## Sursaut ponctuel du micro-glitch du shader — pour souligner un instant
## narratif précis (ex. RelayGhost qui "en dit trop", voir le tag [#glitch]
## dans dialogue_balloon.gd/conversation_view.gd) sans construire un nouvel
## effet dédié. `null` réinitialise un paramètre de shader à sa valeur par
## défaut déclarée dans le .gdshader (voir ShaderMaterial.set_shader_parameter).
func pulse_glitch() -> void:
	_grain_material.set_shader_parameter("glitch_chance", GLITCH_PULSE_CHANCE)
	_grain_material.set_shader_parameter("glitch_intensity", GLITCH_PULSE_INTENSITY)
	await get_tree().create_timer(GLITCH_PULSE_SECONDS).timeout
	_grain_material.set_shader_parameter("glitch_chance", null)
	_grain_material.set_shader_parameter("glitch_intensity", null)
