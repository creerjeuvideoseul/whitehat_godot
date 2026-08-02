extends Control
## "Nouvelle partie" screen: collects a pseudo (alnum + underscore, 2-20
## chars) and a password (no charset restriction, 20 chars max), then hands
## the login to PlayerSession and moves on to the welcome screen.

const INVALID_PSEUDO_CHARS := "[^A-Za-z0-9_]"

@onready var _pseudo_edit: LineEdit = %PseudoEdit
@onready var _password_edit: LineEdit = %PasswordEdit
@onready var _error_label: Label = %ErrorLabel
@onready var _connect_button: Button = %ConnectButton
@onready var _back_button: Button = %BackButton
@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer

var _invalid_chars_regex := RegEx.new()
var _start_ticks_msec: int = 0

func _ready() -> void:
	_invalid_chars_regex.compile(INVALID_PSEUDO_CHARS)
	_start_ticks_msec = Time.get_ticks_msec()

	_pseudo_edit.text_changed.connect(_on_pseudo_text_changed)
	_connect_button.pressed.connect(_on_connect_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()

	_pseudo_edit.grab_focus()

func _update_uptime_label() -> void:
	var elapsed_sec: int = int((Time.get_ticks_msec() - _start_ticks_msec) / 1000.0)
	var days: int = elapsed_sec / 86400
	var hours: int = (elapsed_sec % 86400) / 3600
	var minutes: int = (elapsed_sec % 3600) / 60
	_uptime_label.text = "Up %dd %02d:%02d" % [days, hours, minutes]

func _on_pseudo_text_changed(new_text: String) -> void:
	var filtered := _invalid_chars_regex.sub(new_text, "", true)
	if filtered != new_text:
		var caret := _pseudo_edit.caret_column
		_pseudo_edit.text = filtered
		_pseudo_edit.caret_column = clampi(caret - 1, 0, filtered.length())
	_error_label.text = ""

func _on_connect_pressed() -> void:
	var pseudo := _pseudo_edit.text.strip_edges()
	if pseudo.length() < 2:
		_error_label.text = "Pseudo requis : 2 à 20 caractères (lettres, chiffres, _)."
		return
	PlayerSession.set_login(pseudo, _password_edit.text)
	SaveManager.save_checkpoint("res://scenes/welcome.tscn")
	get_tree().change_scene_to_file("res://scenes/welcome.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://control.tscn")
