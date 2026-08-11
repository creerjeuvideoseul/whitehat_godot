extends RefCounted
class_name SmsDatabase
## Charge un dump de conversations SMS façon data/alizee_smsbox.json (fr ET
## en). Même principe que MailDatabase : `data_path` n'est pas figé en
## constante, chaque mission aura son propre fichier — voir SmsSection.data_path.

const DEFAULT_LOCALE := "fr"

## languageCode -> Array[SmsConversation].
var _conversations_by_locale: Dictionary = {}


func _init(data_path: String) -> void:
	_load(data_path)


## Conversations de la boîte demandée, dans l'ordre du JSON.
func get_conversations() -> Array[SmsConversation]:
	var locale := _resolve_locale()
	return _conversations_by_locale.get(locale, [])


func _resolve_locale() -> String:
	if _conversations_by_locale.has(Settings.locale):
		return Settings.locale
	return DEFAULT_LOCALE


func _load(data_path: String) -> void:
	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("translations"):
		return
	for block: Dictionary in parsed["translations"]:
		var locale: String = block.get("languageCode", "")
		var conversations: Array[SmsConversation] = []
		for raw: Dictionary in block.get("conversations", []):
			conversations.append(SmsConversation.from_dict(raw))
		_conversations_by_locale[locale] = conversations
