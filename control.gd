extends Control
## Main menu screen: wires up the numbered menu list and the fake
## "system uptime" readout in the top bar.

const OPTIONS_PANEL := preload("res://scenes/options/options_panel.tscn")
const MENU_MUSIC := preload("res://assets/audio/Autohacker Dark Console Royalty Free Music.mp3")

@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer

@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _continue_button: MenuItem = %ContinueButton
@onready var _quit_button: Button = %QuitButton
@onready var _new_game_confirm_dialog: ConfirmationDialog = %NewGameConfirmDialog

var _start_ticks_msec: int = 0
var _options_panel: Control = null

func _ready() -> void:
	_start_ticks_msec = Time.get_ticks_msec()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_new_game_confirm_dialog.confirmed.connect(_start_new_game)
	_new_game_confirm_dialog.get_cancel_button().text = "COMMON_CANCEL"

	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()

	_continue_button.set_locked(not SaveManager.has_save())
	_new_game_button.grab_focus()

	MusicPlayer.play(MENU_MUSIC)

func _update_uptime_label() -> void:
	var elapsed_sec: int = int((Time.get_ticks_msec() - _start_ticks_msec) / 1000.0)
	var days: int = elapsed_sec / 86400
	var hours: int = (elapsed_sec % 86400) / 3600
	var minutes: int = (elapsed_sec % 3600) / 60
	_uptime_label.text = "Up %dd %02d:%02d" % [days, hours, minutes]

func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		_new_game_confirm_dialog.popup_centered()
		return
	_start_new_game()

func _start_new_game() -> void:
	SaveManager.delete_save()
	MusicPlayer.stop()
	get_tree().change_scene_to_file("res://scenes/introduction.tscn")

func _on_options_pressed() -> void:
	if is_instance_valid(_options_panel):
		return
	_options_panel = OPTIONS_PANEL.instantiate()
	add_child(_options_panel)

func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	_continue_button.disabled = true
	MusicPlayer.stop()
	await SceneTransition.fade_out()
	SaveManager.restore_player_session()
	get_tree().change_scene_to_file(SaveManager.get_checkpoint_scene())
	SceneTransition.fade_in()

func _on_quit_pressed() -> void:
	MusicPlayer.stop()
	await get_tree().create_timer(MusicPlayer.DEFAULT_FADE_SECONDS).timeout
	get_tree().quit()
