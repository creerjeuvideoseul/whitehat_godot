extends Control
## Reusable options overlay: a 700x500 card shown on top of whatever scene
## instances it (main menu today, in-game later). Add future settings as
## extra rows inside the "Body" VBox in options_panel.tscn.

@onready var _fr_button: Button = %FrButton
@onready var _en_button: Button = %EnButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_fr_button.button_pressed = Settings.locale == "fr"
	_en_button.button_pressed = Settings.locale == "en"

	_fr_button.pressed.connect(_on_fr_pressed)
	_en_button.pressed.connect(_on_en_pressed)
	_close_button.pressed.connect(_on_close_pressed)

	(_fr_button if Settings.locale == "fr" else _en_button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()


func _on_fr_pressed() -> void:
	Settings.set_locale("fr")


func _on_en_pressed() -> void:
	Settings.set_locale("en")


func _on_close_pressed() -> void:
	queue_free()
