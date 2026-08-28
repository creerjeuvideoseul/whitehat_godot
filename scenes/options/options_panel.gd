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
const WARNING_DIALOG := preload("res://scenes/ui/warning_dialog.tscn")

## Langues disponibles, dans l'ordre d'affichage du menu déroulant — code
## locale -> nom natif de la langue (jamais traduit : une langue s'affiche
## toujours dans son propre nom, quelle que soit la langue active). Ajouter
## une langue plus tard = une ligne ici, rien d'autre à changer dans ce script.
const LANGUAGES := [
	{"locale": "fr", "label": "Français"},
	{"locale": "en", "label": "English"},
]

## Un item par valeur de Settings.DisplayMode, dans le même ordre que l'enum
## (l'index de l'item choisi dans la liste déroulante correspond directement
## à la valeur de l'enum, voir _on_resolution_selected).
const RESOLUTION_LABEL_KEYS := [
	"OPTIONS_RESOLUTION_FULLSCREEN",
	"OPTIONS_RESOLUTION_FULLSCREEN_BORDERLESS",
	"OPTIONS_RESOLUTION_2560",
	"OPTIONS_RESOLUTION_1920",
]

@onready var _language_option: OptionButton = %LanguageOption
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _music_volume_percent_label: Label = %MusicVolumePercentLabel
@onready var _sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var _sfx_volume_percent_label: Label = %SfxVolumePercentLabel
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _hide_indice_colors_option: OptionButton = %HideIndiceColorsOption
@onready var _quit_game_button: Button = %QuitGameButton
@onready var _close_button: Button = %CloseButton

## WarningDialog (voir scenes/ui/warning_dialog.gd), pas ConfirmationDialog —
## même raison que main_menu.gd::_new_game_confirm_dialog (Window clippe le
## halo diffus). Instanciée en code, pas posée dans la scène.
var _quit_game_confirm_dialog: WarningDialog


func _ready() -> void:
	_populate_language_option()
	_language_option.item_selected.connect(_on_language_selected)

	_music_volume_slider.value = Settings.music_volume
	_update_music_volume_label(Settings.music_volume)
	_music_volume_slider.value_changed.connect(_on_music_volume_changed)

	_sfx_volume_slider.value = Settings.sfx_volume
	_update_sfx_volume_label(Settings.sfx_volume)
	_sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	_populate_resolution_option()
	_resolution_option.item_selected.connect(_on_resolution_selected)

	_populate_hide_indice_colors_option()
	_hide_indice_colors_option.item_selected.connect(_on_hide_indice_colors_selected)

	_quit_game_button.visible = get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE
	_quit_game_button.pressed.connect(_on_quit_game_pressed)
	_quit_game_confirm_dialog = WARNING_DIALOG.instantiate()
	add_child(_quit_game_confirm_dialog)
	_quit_game_confirm_dialog.confirmed.connect(_on_quit_game_confirmed)

	_close_button.pressed.connect(_on_close_pressed)

	_language_option.grab_focus()


func _populate_language_option() -> void:
	_language_option.clear()
	for i in LANGUAGES.size():
		_language_option.add_item(LANGUAGES[i]["label"])
		if LANGUAGES[i]["locale"] == Settings.locale:
			_language_option.select(i)


## Choisir un item déclenche directement le changement de langue — pas de
## bouton "valider" séparé, comme demandé.
func _on_language_selected(index: int) -> void:
	Settings.set_locale(LANGUAGES[index]["locale"])
	# Les items de la liste résolution ont été traduits avec tr() au moment de
	# leur ajout (voir _populate_resolution_option) : contrairement à un
	# Label.text assigné directement à une clé, ils ne se retraduisent pas
	# tout seuls quand la langue change — il faut les reconstruire à la main.
	# Même chose pour OUI/NON (voir _populate_hide_indice_colors_option).
	_populate_resolution_option()
	_populate_hide_indice_colors_option()


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


func _populate_resolution_option() -> void:
	var previous_selected := _resolution_option.selected
	_resolution_option.clear()
	for key in RESOLUTION_LABEL_KEYS:
		_resolution_option.add_item(tr(key))
	_resolution_option.select(previous_selected if previous_selected >= 0 else Settings.display_mode)


## L'index choisi correspond directement à la valeur de l'enum Settings.DisplayMode
## (voir RESOLUTION_LABEL_KEYS) — pas de bouton "valider" séparé, le changement
## de résolution/mode de fenêtre s'applique immédiatement au choix.
func _on_resolution_selected(index: int) -> void:
	Settings.set_display_mode(index as Settings.DisplayMode)


## NON à l'index 0 (faux, jeu facile — défaut), OUI à l'index 1 (vrai, plus
## difficile) — voir Settings.hide_indice_colors/DEFAULT_HIDE_INDICE_COLORS.
func _populate_hide_indice_colors_option() -> void:
	var previous_selected := _hide_indice_colors_option.selected
	_hide_indice_colors_option.clear()
	_hide_indice_colors_option.add_item(tr("COMMON_NO"))
	_hide_indice_colors_option.add_item(tr("COMMON_YES"))
	_hide_indice_colors_option.select(previous_selected if previous_selected >= 0 else int(Settings.hide_indice_colors))


func _on_hide_indice_colors_selected(index: int) -> void:
	Settings.set_hide_indice_colors(index == 1)


func _on_close_pressed() -> void:
	queue_free()


func _on_quit_game_pressed() -> void:
	# Explicit tr() (rather than the auto-translation the rest of the project
	# relies on) because this text needs a value substituted in before
	# display; auto-translation only works on the raw key assigned to .text.
	# "Continuer ?" sur sa propre ligne : voir main_menu.gd pour la même
	# construction sur l'avertissement d'écrasement de partie.
	var minutes := SaveManager.get_minutes_since_checkpoint()
	# MessageLabel est rouge par défaut (voir warning_dialog.tscn) : ce message
	# repasse entièrement en blanc via bbcode (voir WarningDialog.set_text),
	# avec "depuis X minutes" qui garde sa mise en évidence <color=important>
	# (voir OPTIONS_QUIT_WARNING, résolue par RichTextMarkup.html_to_bbcode).
	var white_hex := "#%s" % Palette.TEXT_NORMAL.to_html(false)
	var warning := RichTextMarkup.html_to_bbcode(tr("OPTIONS_QUIT_WARNING") % minutes)
	_quit_game_confirm_dialog.set_text(
		"[color=%s]%s\n%s[/color]" % [white_hex, warning, tr("COMMON_CONTINUE_QUESTION")],
		"COMMON_CONFIRM", "COMMON_CANCEL"
	)
	_quit_game_confirm_dialog.show_centered()


func _on_quit_game_confirmed() -> void:
	GameClock.stop_ticking()
	MusicPlayer.stop()
	await SceneTransition.fade_out()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	SceneTransition.fade_in()
	# Freed last so `self` stays valid across the awaits above.
	OptionsMenu.close()
