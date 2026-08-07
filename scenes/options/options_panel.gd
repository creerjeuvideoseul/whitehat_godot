extends Control
## Reusable options overlay: a 700x580 card shown on top of whatever scene
## instances it. Opened/closed globally via OptionsMenu (ÉCHAP anywhere), and
## also reachable by clicking "Options" on the main menu. Add future settings
## as extra rows inside the "Body" VBox in options_panel.tscn.
##
## Main-menu scene path, used to hide "Quitter la partie": that action means
## "abandon the current playthrough", which is meaningless while already on
## the main menu.
const MAIN_MENU_SCENE := "res://main_menu.tscn"

@onready var _fr_button: Button = %FrButton
@onready var _en_button: Button = %EnButton
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _music_volume_percent_label: Label = %MusicVolumePercentLabel
@onready var _sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var _sfx_volume_percent_label: Label = %SfxVolumePercentLabel
@onready var _quit_game_button: Button = %QuitGameButton
@onready var _quit_game_confirm_dialog: ConfirmationDialog = %QuitGameConfirmDialog
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_fr_button.button_pressed = Settings.locale == "fr"
	_en_button.button_pressed = Settings.locale == "en"

	_fr_button.pressed.connect(_on_fr_pressed)
	_en_button.pressed.connect(_on_en_pressed)

	_music_volume_slider.value = Settings.music_volume
	_update_music_volume_label(Settings.music_volume)
	_music_volume_slider.value_changed.connect(_on_music_volume_changed)

	_sfx_volume_slider.value = Settings.sfx_volume
	_update_sfx_volume_label(Settings.sfx_volume)
	_sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	_quit_game_button.visible = get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE
	_quit_game_button.pressed.connect(_on_quit_game_pressed)
	_quit_game_confirm_dialog.confirmed.connect(_on_quit_game_confirmed)
	_quit_game_confirm_dialog.get_cancel_button().text = "COMMON_CANCEL"
	DialogStyle.style_warning_dialog(_quit_game_confirm_dialog)

	_close_button.pressed.connect(_on_close_pressed)

	(_fr_button if Settings.locale == "fr" else _en_button).grab_focus()


func _on_fr_pressed() -> void:
	Settings.set_locale("fr")


func _on_en_pressed() -> void:
	Settings.set_locale("en")


func _on_music_volume_changed(value: float) -> void:
	Settings.set_music_volume(value)
	_update_music_volume_label(value)


func _update_music_volume_label(value: float) -> void:
	_music_volume_percent_label.text = "%d%%" % roundi(value * 100)


func _on_sfx_volume_changed(value: float) -> void:
	Settings.set_sfx_volume(value)
	_update_sfx_volume_label(value)


func _update_sfx_volume_label(value: float) -> void:
	_sfx_volume_percent_label.text = "%d%%" % roundi(value * 100)


func _on_close_pressed() -> void:
	queue_free()


func _on_quit_game_pressed() -> void:
	# Explicit tr() (rather than the auto-translation the rest of the project
	# relies on) because this text needs a value substituted in before
	# display; auto-translation only works on the raw key assigned to .text.
	# "Continuer ?" sur sa propre ligne : voir main_menu.gd pour la même
	# construction sur l'avertissement d'écrasement de partie.
	var minutes := SaveManager.get_minutes_since_checkpoint()
	_quit_game_confirm_dialog.dialog_text = (tr("OPTIONS_QUIT_WARNING") % minutes) + "\n" + tr("COMMON_CONTINUE_QUESTION")
	_quit_game_confirm_dialog.popup_centered()


func _on_quit_game_confirmed() -> void:
	GameClock.stop_ticking()
	MusicPlayer.stop()
	await SceneTransition.fade_out()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	SceneTransition.fade_in()
	# Freed last so `self` stays valid across the awaits above.
	OptionsMenu.close()
