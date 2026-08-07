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

## Build-time flag, not a player setting (not persisted, not exposed in the
## options menu) — hand-flipped before a real release. Gates dev-only tools
## like the desktop's "DEBUG INDICES" button, which must never ship.
const IS_PRODUCTION := false

var locale: String = DEFAULT_LOCALE
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME


func _ready() -> void:
	_load()
	TranslationServer.set_locale(locale)
	_apply_music_volume()
	_apply_sfx_volume()


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


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		locale = config.get_value("general", "locale", DEFAULT_LOCALE)
		music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
		sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)
