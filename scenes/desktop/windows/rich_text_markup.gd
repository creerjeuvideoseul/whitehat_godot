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
## concerne que les données mail/SMS/OSINT) — [color=important] et
## [color=indice] y sont des mots-clés sémantiques ("mot à souligner"/"passage
## indice mis en évidence"), pas des noms de couleur BBCode valides (sans
## résolution, un RichTextLabel les ignore silencieusement et affiche le texte
## en blanc par défaut — bug constaté sur relayghost_intro.dialogue), à
## résoudre vers Palette.TEXT_IMPORTANT/TEXT_HIGHLIGHT avant affichage pour ne
## changer chaque teinte qu'à un seul endroit (voir palette.gd).
static func resolve_dialogue_colors(text: String) -> String:
	var result := text.replace("[color=important]", "[color=#%s]" % Palette.TEXT_IMPORTANT.to_html(false))
	result = result.replace("[color=indice]", "[color=#%s]" % Palette.TEXT_HIGHLIGHT.to_html(false))
	return result


## Convertit le pseudo-HTML très simple utilisé dans les données "brutes"
## (dump de mails, etc.) vers le BBCode natif d'un RichTextLabel : <br>,
## <color=...>/</color>, <b></b>, <i></i>. Volontairement limité à ces 4 tags
## — ce n'est pas un parseur HTML général, juste ce que les fiches du jeu
## utilisent réellement.
##
## "indice" et "important" dans les données sont des mots-clés sémantiques
## ("passage indice mis en évidence" / "mot à souligner"), pas des noms de
## couleur à garder tels quels — ils pointent sur `highlight_color`/
## `important_color` pour ne changer chaque teinte qu'à un seul endroit (voir
## palette.gd) plutôt que dans chaque fichier de données. Par défaut
## Palette.TEXT_HIGHLIGHT/TEXT_IMPORTANT (fond sombre, le cas courant — mail,
## galerie) ; un appelant sur fond clair (bulles SMS pastel) passe la variante
## _ON_LIGHT de chacune à la place (voir Palette.is_light()).
static func html_to_bbcode(text: String, highlight_color: Color = Palette.TEXT_HIGHLIGHT, important_color: Color = Palette.TEXT_IMPORTANT) -> String:
	var result := text.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
	result = result.replace("<b>", "[b]").replace("</b>", "[/b]")
	result = result.replace("<i>", "[i]").replace("</i>", "[/i]")
	result = result.replace("<color=indice>", "[color=#%s]" % highlight_color.to_html(false))
	result = result.replace("<color=important>", "[color=#%s]" % important_color.to_html(false))
	var color_regex := RegEx.new()
	color_regex.compile("<color=([^>]+)>")
	result = color_regex.sub(result, "[color=$1]", true)
	result = result.replace("</color>", "[/color]")
	return result
