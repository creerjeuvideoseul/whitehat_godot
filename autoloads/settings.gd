extends Node
## Autoload singleton: persisted user settings (language, audio volumes).
## Applies saved values before any scene is built, and future options should
## be added here following the same load/save pattern.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "fr"
const MUSIC_BUS := "Music"
const DEFAULT_MUSIC_VOLUME := 0.7
## Voir SfxPlayer.SFX_BUS — même bus, dupliqué ici en const plutôt que
## référencé pour ne pas coupler cet autoload à SfxPlayer juste pour un nom.
const SFX_BUS := "SFX"
## 1.0 (pas d'atténuation) pour ne rien changer au volume perçu tant que le
## joueur n'a jamais touché ce réglage — contrairement à la musique, dont
## 0.7 est un choix de mix déjà en place avant que ce réglage existe.
const DEFAULT_SFX_VOLUME := 1.0

## Presets d'affichage proposés dans les Options — volontairement une liste
## fermée (pas de résolution libre) plutôt qu'un choix de résolution générique :
## le viewport tourne en mode d'échelle "canvas_items" (voir project.godot),
## donc n'importe laquelle de ces 4 options reste toujours safe à appliquer
## sans jamais casser l'affichage (pas de risque d'écran noir à mitiger ici,
## sauf le plein écran exclusif — voir _apply_display_mode).
enum DisplayMode { FULLSCREEN, FULLSCREEN_BORDERLESS, WINDOWED_2560X1440, WINDOWED_1920X1080 }
## Correspond à window_width_override/height_override de project.godot — le
## jeu démarre déjà dans cet état avant même que Settings existe, donc c'est
## la valeur par défaut cohérente tant que le joueur n'a rien choisi.
const DEFAULT_DISPLAY_MODE := DisplayMode.WINDOWED_1920X1080

## Build-time flag, not a player setting (not persisted, not exposed in the
## options menu) — hand-flipped before a real release. Gates dev-only tools
## like the desktop's "DEBUG INDICES" button, which must never ship.
const IS_PRODUCTION := false

## Option "Retirer la couleur des indices (+ difficile)" — NON par défaut
## (jeu facile, indices colorés). Lu par RichTextMarkup (resolve_indice_tags/
## resolve_dialogue_colors/html_to_bbcode) : quand vrai, le texte d'un indice
## PAS ENCORE cliqué/survolé n'est plus coloré (se fond dans le texte normal)
## — le survol et le clic restent inchangés dans les deux cas, seule la
## teinte "au repos" disparaît.
const DEFAULT_HIDE_INDICE_COLORS := false

var locale: String = DEFAULT_LOCALE
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var display_mode: DisplayMode = DEFAULT_DISPLAY_MODE
var hide_indice_colors: bool = DEFAULT_HIDE_INDICE_COLORS
## Horodatage Unix réel du tout premier lancement du jeu par ce joueur — 0
## tant qu'il n'a jamais été enregistré. Survit à une nouvelle partie
## (SaveManager.delete_save() ne touche jamais ce fichier) : c'est une
## propriété de la machine/du profil joueur, pas d'une partie en cours — voir
## BootUptime, qui s'en sert pour l'indice narratif d'uptime des écrans de
## menu.
var first_launch_unix_time: int = 0
## Vrai seulement pendant la session où first_launch_unix_time vient d'être
## généré (aucune valeur trouvée au chargement) — voir BootUptime, qui a
## besoin de distinguer "on est en train de vivre ce tout premier lancement"
## de "on relit une référence posée lors d'une session précédente".
var is_first_launch_session: bool = false


func _ready() -> void:
	_load()
	is_first_launch_session = first_launch_unix_time == 0
	if is_first_launch_session:
		first_launch_unix_time = int(Time.get_unix_time_from_system())
		_save()
	TranslationServer.set_locale(locale)
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_display_mode()


## Change the active language and persist the choice immediately.
func set_locale(new_locale: String) -> void:
	if new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	_save()


## Change the music bus volume (linear 0..1) and persist it immediately.
func set_music_volume(linear_volume: float) -> void:
	music_volume = clampf(linear_volume, 0.0, 1.0)
	_apply_music_volume()
	_save()


func _apply_music_volume() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(music_volume))


## Change le volume du bus SFX (linéaire 0..1) et le persiste immédiatement —
## couvre tout le jeu (indices, notifications, choix de dialogue...) puisque
## SfxPlayer joue systématiquement sur ce bus, jamais sur Master directement.
func set_sfx_volume(linear_volume: float) -> void:
	sfx_volume = clampf(linear_volume, 0.0, 1.0)
	_apply_sfx_volume()
	_save()


func _apply_sfx_volume() -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(sfx_volume))


## Change le mode d'affichage (plein écran / plein écran sans bordure / une
## des 2 tailles fenêtrées) et le persiste immédiatement.
func set_display_mode(new_mode: DisplayMode) -> void:
	if new_mode == display_mode:
		return
	display_mode = new_mode
	_apply_display_mode()
	_save()


## Change l'option "Retirer la couleur des indices" et la persiste
## immédiatement — pas d'"_apply" séparé comme les autres réglages : lu
## directement depuis Settings à chaque construction/reconstruction de texte
## par RichTextMarkup, donc déjà à jour dès la prochaine ligne affichée/
## fenêtre rouverte, sans rien à pousser activement ici.
func set_hide_indice_colors(value: bool) -> void:
	hide_indice_colors = value
	_save()


func _apply_display_mode() -> void:
	match display_mode:
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayMode.FULLSCREEN_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.WINDOWED_2560X1440:
			_apply_windowed_size(Vector2i(2560, 1440))
		DisplayMode.WINDOWED_1920X1080:
			_apply_windowed_size(Vector2i(1920, 1080))


## Repasse en fenêtré (si on venait d'un des 2 modes plein écran) puis
## applique la taille demandée, recentrée sur l'écran — sinon la fenêtre
## réapparaît là où le dernier plein écran l'avait laissée, potentiellement
## hors-écran ou dans un coin sur un setup multi-écrans.
func _apply_windowed_size(size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen_size - size) / 2)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		locale = config.get_value("general", "locale", DEFAULT_LOCALE)
		music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
		sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
		# int(...) : ConfigFile renvoie l'entier stocké tel quel, mais le typer
		# explicitement en DisplayMode évite une valeur hors-enum si le fichier
		# a été modifié à la main ou vient d'une version antérieure du jeu.
		display_mode = int(config.get_value("display", "display_mode", DEFAULT_DISPLAY_MODE)) as DisplayMode
		first_launch_unix_time = int(config.get_value("general", "first_launch_unix_time", 0))
		hide_indice_colors = config.get_value("gameplay", "hide_indice_colors", DEFAULT_HIDE_INDICE_COLORS)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "display_mode", display_mode)
	config.set_value("general", "first_launch_unix_time", first_launch_unix_time)
	config.set_value("gameplay", "hide_indice_colors", hide_indice_colors)
	config.save(SETTINGS_PATH)
