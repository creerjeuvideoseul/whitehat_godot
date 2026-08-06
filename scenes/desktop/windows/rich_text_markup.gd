extends RefCounted
class_name RichTextMarkup
## Petites conversions de texte partagées par tout ce qui affiche du contenu
## "trouvé" dans une donnée JSON (fiche OSINT, mail...) via un RichTextLabel.
## Regroupé ici pour ne pas dupliquer la même regex à chaque nouvel écran —
## voir OsintWindow (fiches) et MailSection (mails).


## Le JSON marque un indice à débloquer avec une balise perso <indice
## id="..."> (pas du BBCode natif — évite d'écrire un RichTextEffect
## personnalisé juste pour ça). Contrairement à l'ancien comportement, ces
## fonctions ne débloquent plus rien elles-mêmes : un texte construit dans
## l'arbre de scène n'est pas forcément visible à l'écran (ex. un message SMS
## plus haut dans l'historique, un mail qui déborde du cadre) — c'est
## l'appelant qui décide quand un id est réellement visible avant de faire
## ClueManager.unlock() lui-même (voir IndiceRevealTracker pour le cas
## scrollable ; un appel immédiat reste correct pour un contenu toujours vu
## d'un coup, comme une bulle de chat en direct ou une photo de galerie
## ouverte en grand).

## Le texte affichable, balise retirée, sans effet de bord.
static func strip_indice_tags(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("<indice id=\"([^\"]+)\">(.*?)</indice>")
	return regex.sub(text, "$2", true)


## Les ids d'indices présents dans le texte, dans l'ordre d'apparition.
static func extract_indice_ids(text: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("<indice id=\"([^\"]+)\">")
	var ids: Array[String] = []
	for result in regex.search_all(text):
		ids.append(result.get_string(1))
	return ids


## Découpe un texte en segments consécutifs autour des balises <indice> (id
## vide = segment hors balise) — pour un bloc de texte unique qui peut
## contenir un indice au milieu (ex. corps d'un mail) : chaque segment peut
## alors devenir son propre Control, individuellement surveillable par
## IndiceRevealTracker, plutôt qu'un seul RichTextLabel dont on ne saurait
## dire quelle portion est vraiment visible.
static func split_by_indice(text: String) -> Array[Dictionary]:
	var regex := RegEx.new()
	regex.compile("<indice id=\"([^\"]+)\">(.*?)</indice>")
	var segments: Array[Dictionary] = []
	var cursor := 0
	for result in regex.search_all(text):
		var full_start: int = result.get_start()
		var full_end: int = result.get_end()
		if full_start > cursor:
			segments.append({"text": text.substr(cursor, full_start - cursor), "clue_id": ""})
		segments.append({"text": result.get_string(2), "clue_id": result.get_string(1)})
		cursor = full_end
	if cursor < text.length():
		segments.append({"text": text.substr(cursor), "clue_id": ""})
	return segments


## Convertit le pseudo-HTML très simple utilisé dans les données "brutes"
## (dump de mails, etc.) vers le BBCode natif d'un RichTextLabel : <br>,
## <color=...>/</color>, <b></b>, <i></i>. Volontairement limité à ces 4 tags
## — ce n'est pas un parseur HTML général, juste ce que les fiches du jeu
## utilisent réellement.
static func html_to_bbcode(text: String) -> String:
	var result := text.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
	result = result.replace("<b>", "[b]").replace("</b>", "[/b]")
	result = result.replace("<i>", "[i]").replace("</i>", "[/i]")
	var color_regex := RegEx.new()
	color_regex.compile("<color=([^>]+)>")
	result = color_regex.sub(result, "[color=$1]", true)
	result = result.replace("</color>", "[/color]")
	return result
