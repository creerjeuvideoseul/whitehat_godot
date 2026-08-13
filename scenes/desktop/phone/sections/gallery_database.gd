extends RefCounted
class_name GalleryDatabase
## Charge un dump de publications façon data/alizee_galerie.json (fr ET en).
## Même principe que MailDatabase/SmsDatabase : `data_path` n'est pas figé en
## constante, chaque mission aura son propre fichier — voir GallerySection.data_path.

const DEFAULT_LOCALE := "fr"

## languageCode -> Array[GalleryPost].
var _posts_by_locale: Dictionary = {}


func _init(data_path: String) -> void:
	_load(data_path)


## Publications de la boîte demandée, des plus anciennes aux plus récentes
## (date de prise, pas l'ordre brut/postId du JSON).
func get_posts() -> Array[GalleryPost]:
	var locale := _resolve_locale()
	var result: Array[GalleryPost] = _posts_by_locale.get(locale, []).duplicate()
	result.sort_custom(func(a: GalleryPost, b: GalleryPost) -> bool: return a.timestamp < b.timestamp)
	return result


func _resolve_locale() -> String:
	if _posts_by_locale.has(Settings.locale):
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
		var posts: Array[GalleryPost] = []
		for raw: Dictionary in block.get("posts", []):
			posts.append(GalleryPost.from_dict(raw))
		_posts_by_locale[locale] = posts
