extends RefCounted
class_name MailEntry
## Un mail du dump JSON chargé par MailDatabase. Les clés du JSON restent en
## anglais et fixes dans le temps (contrairement à osint_characters.json) —
## seuls subject/html_content/meta_info changent d'une langue à l'autre.

var mail_id: int
var sender: String
var receiver: String
var avatar_path: String
## Nom affiché de l'interlocuteur (l'expéditeur ou destinataire réel, jamais
## le joueur) — le JSON ne fournit qu'une adresse mail brute pour
## sender/receiver, ce champ porte le nom lisible correspondant.
var correspondent_name: String
var subject: String
var timestamp: String
var is_sent_box: bool
var is_crypted: bool
var html_content: String
## Dictionnaire libre clé -> valeur (ex. IP, serveur...), affiché seulement
## si non vide via le bouton "VIEW METADATA".
var meta_info: Dictionary


static func from_dict(data: Dictionary) -> MailEntry:
	var entry := MailEntry.new()
	entry.mail_id = int(data.get("mailId", -1))
	entry.sender = str(data.get("sender", ""))
	entry.receiver = str(data.get("receiver", ""))
	entry.avatar_path = str(data.get("avatar", ""))
	entry.correspondent_name = str(data.get("correspondentName", ""))
	entry.subject = str(data.get("subject", ""))
	entry.timestamp = str(data.get("timestamp", ""))
	entry.is_sent_box = int(data.get("isSentBox", 0)) == 1
	entry.is_crypted = int(data.get("isCrypted", 0)) == 1
	entry.html_content = str(data.get("html_content", ""))
	entry.meta_info = data.get("meta_info", {})
	return entry


## L'interlocuteur à afficher dans la liste : le destinataire pour un mail
## envoyé, l'expéditeur sinon — jamais le joueur lui-même.
func correspondent_address() -> String:
	return receiver if is_sent_box else sender


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
