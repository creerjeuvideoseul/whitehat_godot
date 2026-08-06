extends RefCounted
class_name GalleryPost
## Une publication de la Galerie du dump JSON chargé par GalleryDatabase. Les
## clés du JSON restent en anglais et fixes dans le temps, comme MailEntry/
## SmsEntry — seuls title/description/comments changent d'une langue à l'autre.

var post_id: int
var picture_path: String
var title: String
var timestamp: String
var nb_like: int
var is_crypted: bool
## Id d'indice (data/clues.txt) débloqué à l'ouverture du détail de cette
## publication — vide si cette publication n'en révèle aucun.
var indice: String
var description: String
var comments: Array[GalleryComment] = []


static func from_dict(data: Dictionary) -> GalleryPost:
	var post := GalleryPost.new()
	post.post_id = int(data.get("postId", -1))
	post.picture_path = str(data.get("picture", ""))
	post.title = str(data.get("title", ""))
	post.timestamp = str(data.get("timestamp", ""))
	post.nb_like = int(data.get("nbLike", 0))
	post.is_crypted = int(data.get("isCrypted", 0)) == 1
	post.indice = str(data.get("indice", ""))
	post.description = str(data.get("description", ""))
	for raw: Dictionary in data.get("comments", []):
		post.comments.append(GalleryComment.from_dict(raw))
	return post
