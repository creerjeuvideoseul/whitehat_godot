extends RefCounted
class_name MailDatabase
## Charge un dump de mails façon data/alizee_mailbox.json (une boîte par
## personnage, en fr ET en). Contrairement à OsintDatabase, `data_path` n'est
## pas figé en constante : chaque mission aura son propre fichier (une autre
## boîte mail), donc c'est au script qui instancie MailDatabase de dire
## laquelle charger — voir MailSection.data_path.

const DEFAULT_LOCALE := "fr"

## languageCode -> Array[MailEntry].
var _mails_by_locale: Dictionary = {}


func _init(data_path: String) -> void:
	_load(data_path)


## Mails de la boîte demandée (envoyés ou reçus), du plus ancien au plus
## récent — même logique de lecture que SmsSection (voir _show_conversation :
## "un dossier qu'on lit depuis le début", pas une appli mail qu'on rouvrirait
## sur le dernier échange).
func get_mails(is_sent_box: bool) -> Array[MailEntry]:
	var locale := _resolve_locale()
	var result: Array[MailEntry] = []
	for mail: MailEntry in _mails_by_locale.get(locale, []):
		if mail.is_sent_box == is_sent_box:
			result.append(mail)
	result.sort_custom(func(a: MailEntry, b: MailEntry) -> bool: return a.timestamp < b.timestamp)
	return result


## Le mail donné par son id, toutes boîtes confondues (envoyés + reçus) — pour
## un mail cité en réponse (voir MailEntry.mail_previous_id), qui peut être de
## l'autre boîte que celui qui le cite (ex. mail 5 reçu qui cite le mail 4
## envoyé). null si l'id ne correspond à rien.
func get_mail_by_id(mail_id: int) -> MailEntry:
	var locale := _resolve_locale()
	for mail: MailEntry in _mails_by_locale.get(locale, []):
		if mail.mail_id == mail_id:
			return mail
	return null


func _resolve_locale() -> String:
	if _mails_by_locale.has(Settings.locale):
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
		var mails: Array[MailEntry] = []
		for raw: Dictionary in block.get("mails", []):
			mails.append(MailEntry.from_dict(raw))
		_mails_by_locale[locale] = mails
