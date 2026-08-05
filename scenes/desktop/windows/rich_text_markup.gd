extends RefCounted
class_name RichTextMarkup
## Petites conversions de texte partagées par tout ce qui affiche du contenu
## "trouvé" dans une donnée JSON (fiche OSINT, mail...) via un RichTextLabel.
## Regroupé ici pour ne pas dupliquer la même regex à chaque nouvel écran —
## voir OsintWindow (fiches) et MailSection (mails).


## Le JSON marque un indice à débloquer avec une balise perso <indice
## id="..."> (pas du BBCode natif — évite d'écrire un RichTextEffect
## personnalisé juste pour ça) : dès qu'un texte l'affichant est montré,
## l'indice se débloque — comme une ligne de dialogue avec [#indice=xxx] —
## puis la balise est retirée pour ne laisser que le texte qu'elle entourait.
static func resolve_indice_tags(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("<indice id=\"([^\"]+)\">(.*?)</indice>")
	for result in regex.search_all(text):
		ClueManager.unlock(result.get_string(1))
	return regex.sub(text, "$2", true)


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
