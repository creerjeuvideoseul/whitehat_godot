extends Control
## Main menu screen: wires up the numbered menu list and the fake
## "system uptime" readout in the top bar.

const MENU_MUSIC := preload("res://assets/audio/Autohacker Dark Console Royalty Free Music.mp3")
const WARNING_DIALOG := preload("res://scenes/ui/warning_dialog.tscn")
const CREDITS_WINDOW := preload("res://scenes/credits.tscn")

@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer
@onready var _credit_label: RichTextLabel = %CreditLabel

@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _continue_button: MenuItem = %ContinueButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton

## WarningDialog (voir scenes/ui/warning_dialog.gd) plutôt que
## ConfirmationDialog : ConfirmationDialog hérite de Window, qui clippe le
## halo diffus voulu autour de cette boîte — voir dialog_style.gd pour
## l'historique. Instanciée en code (comme ClueBoardTooltip) plutôt que posée
## dans la scène : elle n'a pas de position/taille fixe à éditer dans
## l'éditeur, tout se calcule au premier affichage (voir show_centered()).
var _new_game_confirm_dialog: WarningDialog
## Instanciée à la demande (voir _on_credits_pressed), pas dans _ready comme
## _new_game_confirm_dialog : contrairement au WarningDialog, systématiquement
## nécessaire au moindre clic sur "Nouvelle partie", les crédits ne sont
## consultés qu'occasionnellement — même paresse que
## desktop.gd::_on_thought_log_button_pressed pour ThoughtLogWindow.
var _credits_window: CreditsWindow

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_new_game_confirm_dialog = WARNING_DIALOG.instantiate()
	add_child(_new_game_confirm_dialog)
	_new_game_confirm_dialog.confirmed.connect(_start_new_game)
	# "Continuer ?" sur sa propre ligne : construit en code plutôt qu'en dur
	# dans le .csv, un saut de ligne réel dans une cellule CSV n'étant pas
	# fiable à l'import (le parseur de Godot lit une ligne physique à la
	# fois) — voir aussi options_panel.gd pour l'avertissement de sortie.
	# MessageLabel est rouge par défaut (voir warning_dialog.tscn) : seule la
	# question de confirmation reste rouge, l'avertissement lui-même repasse en
	# blanc via bbcode (même recette que clue_board_window.gd::_on_generate_report_button_pressed).
	var white_hex := "#%s" % Palette.TEXT_NORMAL.to_html(false)
	_new_game_confirm_dialog.set_text(
		"[color=%s]%s[/color]\n\n%s" % [white_hex, tr("NEWGAME_OVERWRITE_WARNING"), tr("NEWGAME_RESTART_CONFIRM_QUESTION")],
		"COMMON_CONFIRM", "COMMON_CANCEL"
	)

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
		_new_game_confirm_dialog.show_centered()
		return
	_start_new_game()

func _start_new_game() -> void:
	# SaveManager.delete_save() efface aussi StoryVars/ClueManager (voir sa
	# doc) : une "Nouvelle partie" repart bien de zéro, pas seulement le
	# fichier de sauvegarde.
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

## Fenêtre superposée (voir CreditsWindow ci-dessus), pas de scene change : la
## musique du menu (MENU_MUSIC) continue de jouer sans coupure ni redémarrage
## pendant que les crédits sont consultés.
func _on_credits_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	if not is_instance_valid(_credits_window):
		_credits_window = CREDITS_WINDOW.instantiate()
		add_child(_credits_window)
	_credits_window.refresh()
	_credits_window.show()

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
