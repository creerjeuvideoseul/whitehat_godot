extends Control
## "Nouvelle partie" screen: collects a pseudo (alnum + underscore, 2-20
## chars) and a password (no charset restriction, 20 chars max), then hands
## the login to PlayerSession and moves on to the desktop.

const INVALID_PSEUDO_CHARS := "[^A-Za-z0-9_]"
## Joué juste après "SE CONNECTER" — propre à cet écran (un seul appelant),
## donc préchargé ici plutôt que centralisé dans SfxPlayer (voir
## introduction.gd::BOOT_SYSTEM_SFX pour le même principe).
const CONNECT_SFX := preload("res://assets/audio/sound/47313572-startup-sound-variation-fast-315898.mp3")

@onready var _pseudo_edit: LineEdit = %PseudoEdit
@onready var _password_edit: LineEdit = %PasswordEdit
@onready var _error_label: Label = %ErrorLabel
@onready var _connect_button: Button = %ConnectButton
@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer
@onready var _credit_label: RichTextLabel = %CreditLabel

var _invalid_chars_regex := RegEx.new()

func _ready() -> void:
	_invalid_chars_regex.compile(INVALID_PSEUDO_CHARS)

	_pseudo_edit.text_changed.connect(_on_pseudo_text_changed)
	_connect_button.pressed.connect(_on_connect_pressed)
	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()
	## BBCode : ne peut pas compter sur l'auto-traduction d'un RichTextLabel
	## comme pour un Label simple ailleurs dans le projet, donc résolu ici
	## explicitement — même raison que _quit_game_confirm_dialog.dialog_text
	## dans options_panel.gd.
	_credit_label.text = tr("BOOT_CREDIT")

	## Mot de passe pré-rempli par défaut (juste esthétique, non validé :
	## le joueur peut l'effacer/modifier sans que ça change quoi que ce soit).
	_password_edit.text = "*********"

	_pseudo_edit.grab_focus()

func _update_uptime_label() -> void:
	_uptime_label.text = BootUptime.format()

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
		_error_label.text = tr("LOGIN_PSEUDO_ERROR")
		return
	SfxPlayer.play(CONNECT_SFX)
	PlayerSession.set_login(pseudo, _password_edit.text)
	SaveManager.save_checkpoint("res://scenes/desktop/desktop.tscn")
	get_tree().change_scene_to_file("res://scenes/desktop/desktop.tscn")
