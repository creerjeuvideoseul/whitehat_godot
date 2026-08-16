extends Control
## Main menu screen: wires up the numbered menu list and the fake
## "system uptime" readout in the top bar.

const MENU_MUSIC := preload("res://assets/audio/Autohacker Dark Console Royalty Free Music.mp3")

@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer
@onready var _credit_label: RichTextLabel = %CreditLabel

@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _continue_button: MenuItem = %ContinueButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _new_game_confirm_dialog: ConfirmationDialog = %NewGameConfirmDialog

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_new_game_confirm_dialog.confirmed.connect(_start_new_game)
	_new_game_confirm_dialog.get_cancel_button().text = "COMMON_CANCEL"
	# "Continuer ?" sur sa propre ligne : construit en code plutôt qu'en dur
	# dans le .csv, un saut de ligne réel dans une cellule CSV n'étant pas
	# fiable à l'import (le parseur de Godot lit une ligne physique à la
	# fois) — voir aussi options_panel.gd pour l'avertissement de sortie.
	_new_game_confirm_dialog.dialog_text = tr("NEWGAME_OVERWRITE_WARNING") + "\n" + tr("NEWGAME_RESTART_CONFIRM_QUESTION")
	DialogStyle.style_warning_dialog(_new_game_confirm_dialog)
	# Padding + centrage propres à cette dialog précise (pas dans DialogStyle,
	# partagé avec l'avertissement "Quitter la partie" — un changement là-bas
	# toucherait aussi ce second appelant, non demandé ici). Label.theme_
	# override_styles["normal"] sert de boîte à marge : bg transparent, ne
	# fait que réserver du padding autour du texte sans dessiner de fond.
	var new_game_label := _new_game_confirm_dialog.get_label()
	new_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var new_game_label_padding := StyleBoxEmpty.new()
	new_game_label_padding.content_margin_left = 50
	new_game_label_padding.content_margin_top = 50
	new_game_label_padding.content_margin_right = 50
	new_game_label_padding.content_margin_bottom = 50
	new_game_label.add_theme_stylebox_override("normal", new_game_label_padding)

	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()
	## BBCode : voir login.gd pour la même raison (auto-traduction non fiable
	## sur un RichTextLabel, résolu explicitement ici).
	_credit_label.text = tr("BOOT_CREDIT")

	_continue_button.set_locked(not SaveManager.has_save())
	_new_game_button.grab_focus()

	MusicPlayer.play(MENU_MUSIC)

func _update_uptime_label() -> void:
	_uptime_label.text = BootUptime.format()

func _on_new_game_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	if SaveManager.has_save():
		_new_game_confirm_dialog.popup_centered()
		return
	_start_new_game()

func _start_new_game() -> void:
	SaveManager.delete_save()
	GameClock.reset_to_story_start()
	GameClock.start_ticking()
	MusicPlayer.stop()
	await SceneTransition.fade_out()
	get_tree().change_scene_to_file("res://scenes/introduction.tscn")
	SceneTransition.fade_in()

func _on_options_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	OptionsMenu.open()

## Pas de fondu/coupure de musique : même comportement que le bouton
## "Continuer ?" annulé ou l'écran de connexion (login.gd), un simple aller
## vers un autre écran du menu, pas une transition vers le gameplay.
func _on_credits_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	get_tree().change_scene_to_file("res://scenes/credits.tscn")

func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_continue_button.disabled = true
	MusicPlayer.stop()
	await SceneTransition.fade_out()
	SaveManager.restore_player_session()
	SaveManager.restore_game_clock()
	SaveManager.restore_story_vars()
	SaveManager.restore_unlocked_indices()
	GameClock.start_ticking()
	get_tree().change_scene_to_file(SaveManager.get_checkpoint_scene())
	SceneTransition.fade_in()

func _on_quit_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	MusicPlayer.stop()
	await get_tree().create_timer(MusicPlayer.DEFAULT_FADE_SECONDS).timeout
	get_tree().quit()
