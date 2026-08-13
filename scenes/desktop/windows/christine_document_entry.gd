extends RefCounted
class_name ChristineDocumentEntry
## Un document du dump JSON chargé par ChristineDocumentDatabase — même schéma
## bilingue que MailEntry, en plus simple (pas de sender/timestamp, juste un
## titre, un contenu et une image jointe optionnelle).

var document_id: int
var title: String
var content: String
## Chemin res:// d'une image jointe (ex. un certificat scanné), vide si aucune
## — voir hack_pc_mother_window.gd, _build_content_frame.
var image: String


static func from_dict(data: Dictionary) -> ChristineDocumentEntry:
	var entry := ChristineDocumentEntry.new()
	entry.document_id = int(data.get("documentId", -1))
	entry.title = str(data.get("title", ""))
	entry.content = str(data.get("content", ""))
	entry.image = str(data.get("image", ""))
	return entry
