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


## Les fichiers .dialogue (intro, chat) écrivent déjà du BBCode natif
## directement (pas le pseudo-HTML de html_to_bbcode ci-dessous, qui ne
## concerne que les données mail/SMS/OSINT) — [color=important] y est un
## mot-clé sémantique ("mot à souligner"), pas un nom de couleur BBCode
## valide, à résoudre vers Palette.TEXT_IMPORTANT avant affichage pour ne
## changer la teinte qu'à un seul endroit (voir palette.gd).
static func resolve_important_color(text: String) -> String:
	return text.replace("[color=important]", "[color=#%s]" % Palette.TEXT_IMPORTANT.to_html(false))


## Convertit le pseudo-HTML très simple utilisé dans les données "brutes"
## (dump de mails, etc.) vers le BBCode natif d'un RichTextLabel : <br>,
## <color=...>/</color>, <b></b>, <i></i>. Volontairement limité à ces 4 tags
## — ce n'est pas un parseur HTML général, juste ce que les fiches du jeu
## utilisent réellement.
##
## "indice" dans les données est un mot-clé sémantique ("passage indice mis
## en évidence"), pas un nom de couleur à garder tel quel — il pointe sur
## `highlight_color` pour ne changer la teinte qu'à un seul endroit (voir
## palette.gd) plutôt que dans chaque fichier de données. Par défaut
## Palette.TEXT_HIGHLIGHT (fond sombre, le cas courant — mail, galerie) ;
## un appelant sur fond clair (bulles SMS pastel) passe
## Palette.TEXT_HIGHLIGHT_ON_LIGHT à la place (voir Palette.is_light()).
static func html_to_bbcode(text: String, highlight_color: Color = Palette.TEXT_HIGHLIGHT) -> String:
	var result := text.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
	result = result.replace("<b>", "[b]").replace("</b>", "[/b]")
	result = result.replace("<i>", "[i]").replace("</i>", "[/i]")
	result = result.replace("<color=indice>", "[color=#%s]" % highlight_color.to_html(false))
	var color_regex := RegEx.new()
	color_regex.compile("<color=([^>]+)>")
	result = color_regex.sub(result, "[color=$1]", true)
	result = result.replace("</color>", "[/color]")
	return result
