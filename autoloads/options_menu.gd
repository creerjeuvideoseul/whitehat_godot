extends CanvasLayer
## Autoload singleton: owns the single Options panel instance and the global
## ÉCHAP ("ui_cancel") shortcut to open/close it. Because it's an autoload,
## every scene gets pause-menu access for free — no per-scene input handling
## needed, today or for scenes added later.
##
## Wrapped in a CanvasLayer (not a plain Node) so the panel draws above
## whatever scene is currently active regardless of scene-tree order: layer
## is a rendering concept independent of where the node sits in the tree.

const OPTIONS_PANEL := preload("res://scenes/options/options_panel.tscn")
const LAYER := 50

var _panel: Control = null


func _ready() -> void:
	layer = LAYER


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close() if is_open() else open()


func is_open() -> bool:
	return is_instance_valid(_panel)


func open() -> void:
	if is_open():
		return
	_panel = OPTIONS_PANEL.instantiate()
	add_child(_panel)


func close() -> void:
	if is_open():
		_panel.queue_free()
