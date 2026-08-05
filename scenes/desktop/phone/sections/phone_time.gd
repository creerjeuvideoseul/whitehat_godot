extends RefCounted
class_name PhoneTime
## Formatage de date partagé par tous les écrans du téléphone qui affichent
## un timestamp brut du JSON (Mail, SMS...) — voir MailSection/SmsSection.

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
