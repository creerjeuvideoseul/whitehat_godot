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
## Chemin res:// d'une musique à jouer en fond tant que ce mail reste ouvert
## (voir MailSection) — vide par défaut, la plupart des mails n'en ont pas.
var play_music: String
## Chemin res:// d'une image jointe, affichée en miniature 16/9 sous le corps
## du mail — vide par défaut, voir MailSection._build_attachment_thumbnail.
var attach_image: String
## Pensée du joueur affichée à l'ouverture du mail (voir MailSection._show_mail) —
## champ de premier niveau, distinct du "Player_Think" dans meta_info (celui-ci
## se déclenche au dépli de VIEW METADATA, pas à l'ouverture du mail). Vide par
## défaut, la plupart des mails n'en ont pas.
var player_think: String


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
	entry.play_music = str(data.get("play_music", ""))
	entry.attach_image = str(data.get("attach_image", ""))
	entry.player_think = str(data.get("Player_Think", ""))
	return entry


## L'interlocuteur à afficher dans la liste : le destinataire pour un mail
## envoyé, l'expéditeur sinon — jamais le joueur lui-même.
func correspondent_address() -> String:
	return receiver if is_sent_box else sender
