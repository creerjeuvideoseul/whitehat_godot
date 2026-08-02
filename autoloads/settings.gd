extends Node
## Autoload singleton: persisted user settings (currently just language).
## Applies the saved locale before any scene is built, and future options
## (audio, etc.) should be added here following the same load/save pattern.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "fr"

var locale: String = DEFAULT_LOCALE


func _ready() -> void:
	_load()
	TranslationServer.set_locale(locale)


## Change the active language and persist the choice immediately.
func set_locale(new_locale: String) -> void:
	if new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	_save()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		locale = config.get_value("general", "locale", DEFAULT_LOCALE)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.save(SETTINGS_PATH)
