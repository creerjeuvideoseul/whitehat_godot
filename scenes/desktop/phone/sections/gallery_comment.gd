extends RefCounted
class_name GalleryComment
## Un commentaire d'une publication de la Galerie, chargé par GalleryDatabase.

var comment_id: int
var avatar_path: String
var username: String
var message: String


static func from_dict(data: Dictionary) -> GalleryComment:
	var comment := GalleryComment.new()
	comment.comment_id = int(data.get("commentId", -1))
	comment.avatar_path = str(data.get("avatar", ""))
	comment.username = str(data.get("username", ""))
	comment.message = str(data.get("message", ""))
	return comment
