extends CanvasLayer
## Autoload singleton: a full-screen fade-to-black overlay that survives
## change_scene_to_file(), so a scene swap happens while the screen is
## still black instead of popping back to a bright frame mid-transition.
## Call fade_out() before changing scene and fade_in() after arriving.

const DEFAULT_FADE_SECONDS := 0.6

var _rect := ColorRect.new()
var _tween: Tween


func _ready() -> void:
	layer = 100
	_rect.color = Color.BLACK
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


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
