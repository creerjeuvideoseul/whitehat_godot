extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). Owns spawning windows into WindowLayer, the area reserved between
## the header and footer, and wires each window's minimize button to the
## footer's taskbar. The header/footer otherwise manage themselves
## (desktop_header.gd, desktop_footer.gd).

const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const ANONGHOST_AVATAR := preload("res://assets/avatar/anonghost_avatar.png")
const ANONGHOST_DIALOGUE: DialogueResource = preload("res://dialogue/anonghost_intro.dialogue")

@onready var _window_layer: Control = %WindowLayer
@onready var _footer: Control = %DesktopFooter


func _ready() -> void:
	_open_window(_build_anonghost_window())


func _build_anonghost_window() -> ChatWindow:
	var window: ChatWindow = CHAT_WINDOW.instantiate()
	window.contact_id = "anonghost"
	window.contact_name = "AnonGhost"
	window.contact_avatar = ANONGHOST_AVATAR
	window.dialogue_resource = ANONGHOST_DIALOGUE
	return window


func _open_window(window: ChatWindow) -> void:
	window.minimize_requested.connect(_on_window_minimize_requested)
	_window_layer.add_child(window)


func _on_window_minimize_requested(window: Control, window_title: String) -> void:
	_footer.add_minimized_window(window_title, func() -> void: window.show())
