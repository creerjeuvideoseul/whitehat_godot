extends RefCounted
class_name ChristineDocumentDatabase
## Charge data/christine_documents.json (fr ET en) — même structure que
## MailDatabase, mais un contenu figé (un seul jeu de 3 documents, jamais
## réutilisé pour une autre mission) donc pas de data_path exposé comme sur
## MailDatabase.

const DATA_PATH := "res://data/christine_documents.json"
const DEFAULT_LOCALE := "fr"

## languageCode -> Array[ChristineDocumentEntry].
var _documents_by_locale: Dictionary = {}


func _init() -> void:
	_load()


func get_documents() -> Array[ChristineDocumentEntry]:
	var locale := _resolve_locale()
	return _documents_by_locale.get(locale, [])


func _resolve_locale() -> String:
	if _documents_by_locale.has(Settings.locale):
		return Settings.locale
	return DEFAULT_LOCALE


func _load() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("translations"):
		return
	for block: Dictionary in parsed["translations"]:
		var locale: String = block.get("languageCode", "")
		var documents: Array[ChristineDocumentEntry] = []
		for raw: Dictionary in block.get("documents", []):
			documents.append(ChristineDocumentEntry.from_dict(raw))
		_documents_by_locale[locale] = documents
