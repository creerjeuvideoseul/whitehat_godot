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

var _grain_rect := ColorRect.new()


func _ready() -> void:
	layer = LAYER

	_grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = GRAIN_SHADER
	_grain_rect.material = material
	add_child(_grain_rect)

	add_child(CursorTrailOverlay.new())


## Coupe/rétablit uniquement le grain d'écran (scanlines/vignette/flicker) —
## la trainée de curseur n'est pas concernée. Utilisé par GallerySection : les
## scanlines rendaient les vraies photos "rayées", pas seulement l'interface
## (voir gallery_section.gd), donc l'effet se désactive tant qu'une galerie
## (grille ou détail d'une publication, superposé par-dessus) est affichée.
func set_grain_enabled(enabled: bool) -> void:
	_grain_rect.visible = enabled
