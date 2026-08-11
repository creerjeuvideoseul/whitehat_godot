extends RefCounted
class_name SmsConversation
## Une conversation SMS complète (un fil avec un contact) du dump chargé par
## SmsDatabase. Les clés du JSON restent en anglais et fixes dans le temps —
## seuls contactName/message changent d'une langue à l'autre.

var conversation_id: int
var contact_name: String
var avatar_path: String
## Couleur de bulle/texte propres à ce contact (jamais Alizée, toujours fixe —
## voir SmsSection).
var color_background: Color
var color_font: Color
var is_crypted: bool
var messages: Array[SmsEntry] = []


static func from_dict(data: Dictionary) -> SmsConversation:
	var conv := SmsConversation.new()
	conv.conversation_id = int(data.get("conversationId", -1))
	conv.contact_name = str(data.get("contactName", ""))
	conv.avatar_path = str(data.get("avatar", ""))
	conv.color_background = Color.html(str(data.get("colorBackground", "#ffffff")))
	conv.color_font = Color.html(str(data.get("colorFont", "#000000")))
	conv.is_crypted = int(data.get("isCrypted", 0)) == 1
	for raw: Dictionary in data.get("messages", []):
		conv.messages.append(SmsEntry.from_dict(raw))
	return conv
