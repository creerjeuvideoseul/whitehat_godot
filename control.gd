extends Control
## Main menu screen: wires up the numbered menu list and the fake
## "system uptime" readout in the top bar.

const OPTIONS_PANEL := preload("res://scenes/options/options_panel.tscn")

@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer

@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _quit_button: Button = %QuitButton

var _start_ticks_msec: int = 0
var _options_panel: Control = null

func _ready() -> void:
	_start_ticks_msec = Time.get_ticks_msec()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()

	_new_game_button.grab_focus()

func _update_uptime_label() -> void:
	var elapsed_sec: int = int((Time.get_ticks_msec() - _start_ticks_msec) / 1000.0)
	var days: int = elapsed_sec / 86400
	var hours: int = (elapsed_sec % 86400) / 3600
	var minutes: int = (elapsed_sec % 3600) / 60
	_uptime_label.text = "Up %dd %02d:%02d" % [days, hours, minutes]

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/introduction.tscn")

func _on_options_pressed() -> void:
	if is_instance_valid(_options_panel):
		return
	_options_panel = OPTIONS_PANEL.instantiate()
	add_child(_options_panel)

func _on_save_pressed() -> void:
	print("Sauvegarde - à implémenter")

func _on_load_pressed() -> void:
	print("Charger - à implémenter")

func _on_quit_pressed() -> void:
	get_tree().quit()
