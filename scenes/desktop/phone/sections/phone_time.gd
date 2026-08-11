extends RefCounted
class_name PhoneTime
## Formatage de date partagé par tous les écrans du téléphone qui affichent
## un timestamp brut du JSON (Mail, SMS...) — voir MailSection/SmsSection.

## Clé de traduction par mois (1-indexé, voir translations/ui.csv) — utilisée
## par format_full_date() pour un mois écrit en toutes lettres, pas le numéro.
const MONTH_KEYS := [
	"MONTH_1", "MONTH_2", "MONTH_3", "MONTH_4", "MONTH_5", "MONTH_6",
	"MONTH_7", "MONTH_8", "MONTH_9", "MONTH_10", "MONTH_11", "MONTH_12",
]

## "2030-01-18T22:30:00" -> "18/01/2030 22:30" : format numérique JJ/MM/AAAA,
## sans les secondes. Découpage de chaîne plutôt que Time.get_datetime_dict_from_datetime_string
## pour rester lisible même si le format source varie légèrement (pas de fuseau, etc.).
static func format_timestamp(raw_timestamp: String) -> String:
	var parts := raw_timestamp.split("T")
	if parts.size() < 2:
		return raw_timestamp
	var date_parts := parts[0].split("-")
	var time_parts := parts[1].split(":")
	if date_parts.size() < 3 or time_parts.size() < 2:
		return raw_timestamp
	return "%s/%s/%s %s:%s" % [date_parts[2], date_parts[1], date_parts[0], time_parts[0], time_parts[1]]


## "2030-01-18T22:30:00" -> "18 janvier 2030" : mois en toutes lettres et
## traduit (voir MONTH_KEYS), pour la barre de séparation de date entre deux
## messages (voir SmsSection). TranslationServer.translate() plutôt que
## tr() : cette classe n'est pas un Node, pas de self sur lequel l'appeler.
static func format_full_date(raw_timestamp: String) -> String:
	var date_parts := raw_timestamp.split("T")[0].split("-")
	if date_parts.size() < 3:
		return raw_timestamp
	var month_index := clampi(int(date_parts[1]) - 1, 0, MONTH_KEYS.size() - 1)
	var month_name := TranslationServer.translate(MONTH_KEYS[month_index])
	return "%s %s %s" % [date_parts[2], month_name, date_parts[0]]


## Vrai si les deux timestamps bruts ne tombent pas le même jour calendaire —
## pour savoir où insérer la barre de séparation de date entre deux messages
## consécutifs (voir SmsSection._build_message_row).
static func is_different_day(raw_timestamp_a: String, raw_timestamp_b: String) -> bool:
	return raw_timestamp_a.split("T")[0] != raw_timestamp_b.split("T")[0]
