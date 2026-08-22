extends RefCounted
class_name RichTextMarkup
## Petites conversions de texte partagées par tout ce qui affiche du contenu
## "trouvé" dans une donnée JSON (fiche OSINT, mail...) via un RichTextLabel.
## Regroupé ici pour ne pas dupliquer la même regex à chaque nouvel écran —
## voir OsintWindow (fiches) et MailSection (mails).


## Le JSON marque un indice cliquable avec une balise perso <indice
## id="..."> (pas du BBCode natif — évite d'écrire un RichTextEffect
## personnalisé juste pour ça), qui enveloppe toujours un <color=indice>. Un
## indice ne se débloque plus à la simple apparition du texte à l'écran mais
## au clic du joueur sur ce passage (voir resolve_indice_tags, qui transforme
## la balise en [url=id] cliquable, et wire_indice_interactions, qui câble le
## survol/clic d'un RichTextLabel construit avec ce texte).

## Résout les balises <indice id="X"><color=indice>...</color></indice> en
## BBCode [url=X][color=#hex]...[/color][/url] cliquable — la couleur choisie
## dépend de l'état de l'indice : `clicked_color` s'il est déjà débloqué
## (ClueManager.is_unlocked, seul chemin de déblocage désormais) ou en cours
## de survol (`hovered_id`), `highlight_color` sinon. Un <color=indice> qui ne
## serait PAS enveloppé par un <indice id> (cas réel dans
## osint_characters.json, un mot de passe répété en clair une seconde fois)
## n'est pas concerné ici : il reste une simple teinte, résolue plus tard par
## html_to_bbcode.
##
## Reconstruction manuelle de la chaîne plutôt que RegEx.sub : la couleur de
## remplacement dépend de l'id de CHAQUE match (état différent par indice),
## alors que RegEx.sub n'accepte qu'un remplacement fixe, pas une fonction.
static func resolve_indice_tags(
	text: String,
	highlight_color: Color = Palette.TEXT_HIGHLIGHT,
	clicked_color: Color = Palette.TEXT_CLUE_CLICKED,
	hovered_id: String = ""
) -> String:
	var regex := RegEx.new()
	regex.compile("<indice id=\"([^\"]+)\">(.*?)</indice>")
	var result := ""
	var last_end := 0
	for m in regex.search_all(text):
		result += text.substr(last_end, m.get_start() - last_end)
		var id := m.get_string(1)
		var inner := m.get_string(2)
		var color := clicked_color if (ClueManager.is_unlocked(id) or id == hovered_id) else highlight_color
		inner = inner.replace("<color=indice>", "[color=#%s]" % color.to_html(false)).replace("</color>", "[/color]")
		result += "[url=%s]%s[/url]" % [id, inner]
		last_end = m.get_end()
	result += text.substr(last_end)
	return result


## Câble le survol/clic d'un RichTextLabel construit avec du texte contenant
## des passages [url=id] cliquables (voir resolve_indice_tags/
## resolve_dialogue_colors) : survol -> curseur main + `rebuild` rejoué avec
## l'id survolé (recolore ce passage en clicked_color le temps du survol) ;
## sortie -> curseur normal + `rebuild` rejoué sans id survolé (repasse dans
## l'état réel, déjà cliqué ou non) ; clic -> ClueManager.mark_clicked(id)
## (débloque + prévient desktop.gd pour l'encart central/le panneau latéral)
## puis `rebuild` rejoué. `rebuild` reçoit l'id actuellement survolé ("" si
## aucun) et doit réappliquer label.text avec la bonne couleur pour cet id —
## un seul endroit pour ce protocole plutôt que de le dupliquer dans chaque
## écran qui affiche du texte à indices.
##
## Déconnecte d'abord tout câblage précédent : un label recréé à chaque rendu
## (mail, SMS, fiche OSINT...) n'en a jamais, mais un label réutilisé d'une
## ligne à l'autre (DialogueLabel de DialogueBalloon/ChatBubble, une seule
## instance pour toute une conversation) accumulerait sinon une connexion par
## ligne portant un indice, chacune capturant le texte brut de SA propre
## ligne — un clic plus tard aurait alors rejoué toutes ces closures à la
## fois, dont des lignes déjà quittées depuis longtemps.
static func wire_indice_interactions(label: RichTextLabel, rebuild: Callable) -> void:
	for connection in label.meta_hover_started.get_connections():
		label.meta_hover_started.disconnect(connection["callable"])
	for connection in label.meta_hover_ended.get_connections():
		label.meta_hover_ended.disconnect(connection["callable"])
	for connection in label.meta_clicked.get_connections():
		label.meta_clicked.disconnect(connection["callable"])
	label.meta_hover_started.connect(func(meta: Variant) -> void:
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rebuild.call(str(meta))
	)
	label.meta_hover_ended.connect(func(_meta: Variant) -> void:
		label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		rebuild.call("")
	)
	label.meta_clicked.connect(func(meta: Variant) -> void:
		ClueManager.mark_clicked(str(meta))
		rebuild.call("")
	)


## Les fichiers .dialogue (intro, chat) écrivent déjà du BBCode natif
## directement (pas le pseudo-HTML de html_to_bbcode ci-dessous, qui ne
## concerne que les données mail/SMS/OSINT) — [color=important] et
## [color=indice] y sont des mots-clés sémantiques ("mot à souligner"/"passage
## indice mis en évidence"), pas des noms de couleur BBCode valides (sans
## résolution, un RichTextLabel les ignore silencieusement et affiche le texte
## en blanc par défaut — bug constaté sur relayghost_intro.dialogue), à
## résoudre avant affichage (voir _outline_important/Palette.TEXT_HIGHLIGHT)
## pour ne changer chaque teinte qu'à un seul endroit (voir palette.gd).
##
## clue_id est l'id porte par le tag [#indice=xxx] de LA ligne de dialogue
## (recupere par l'appelant via DialogueLine.get_tag_value, une ligne ne
## porte jamais qu'un seul indice, donc un seul [color=indice]...[/color] a la
## fois) : quand il est fourni, ce passage devient un [url=clue_id] cliquable,
## meme logique de couleur que resolve_indice_tags (TEXT_CLUE_CLICKED si
## ClueManager.is_unlocked(clue_id) ou survole, TEXT_HIGHLIGHT sinon). Sans
## clue_id (ligne sans tag [#indice=...]), un eventuel [color=indice] reste
## resolu simplement, non cliquable, ne devrait pas arriver avec les donnees
## actuelles, garde defensive.
## Épaisseur du liseré autour d'un passage "important" — voir
## _outline_important ci-dessous. Valeur par défaut (tous les écrans à fond
## sombre, et les SMS à bulle sombre).
const IMPORTANT_OUTLINE_SIZE := 16
## SMS à bulle CLAIRE (pastel) uniquement — voir sms_section.gd. Même
## couleur/écriture que le reste (Palette.IMPORTANT_OUTLINE, écriture forcée
## en blanc), seule la taille du liseré diffère.
const IMPORTANT_OUTLINE_SIZE_SMS_LIGHT := 12

## "important" (dialogues [color=important] comme données JSON
## <color=important>, voir resolve_dialogue_colors/html_to_bbcode ci-dessous)
## se résout en texte normal cerné d'un liseré (Palette.IMPORTANT_OUTLINE),
## pas en rouge plein ni en gras/italique/taille — choix validé après essais
## successifs, appliqué partout où ce mot-clé apparaît (voir palette.gd).
## `pattern` capture le texte intérieur en groupe 1 ; regex (pas un simple
## replace de la balise ouvrante) car il faut aussi remplacer LA bonne
## fermeture par [/outline_size][/outline_color], jamais une fermeture
## appartenant à un [color=indice]/<color=indice> voisin dans le même texte.
## `text_color` : Color.TRANSPARENT (défaut) laisse le texte dans sa couleur
## héritée — voir html_to_bbcode pour le cas SMS fond clair, où les couleurs
## s'inversent (écriture blanche forcée, plutôt que le texte sombre hérité de
## la bulle pastel) en plus du liseré fin. `outline_color` : Palette.IMPORTANT_OUTLINE
## par défaut, mais un appelant peut passer une autre couleur (ex. la couleur
## d'écriture propre à sa cellule, voir sms_section.gd) plutôt que la teinte
## fixe.
static func _outline_important(text: String, pattern: String, outline_size: int = IMPORTANT_OUTLINE_SIZE, text_color: Color = Color.TRANSPARENT, outline_color: Color = Palette.IMPORTANT_OUTLINE) -> String:
	var regex := RegEx.new()
	regex.compile(pattern)
	var inner := "[color=#%s]$1[/color]" % text_color.to_html(false) if text_color.a > 0.0 else "$1"
	var replacement := "[outline_color=#%s][outline_size=%d]%s[/outline_size][/outline_color]" % [outline_color.to_html(false), outline_size, inner]
	return regex.sub(text, replacement, true)


static func resolve_dialogue_colors(text: String, clue_id: String = "", hovered_id: String = "") -> String:
	var result := _outline_important(text, "\\[color=important\\](.*?)\\[/color\\]")
	if clue_id.is_empty():
		result = result.replace("[color=indice]", "[color=#%s]" % Palette.TEXT_HIGHLIGHT.to_html(false))
	else:
		var color := Palette.TEXT_CLUE_CLICKED if (ClueManager.is_unlocked(clue_id) or clue_id == hovered_id) else Palette.TEXT_HIGHLIGHT
		var regex := RegEx.new()
		regex.compile("\\[color=indice\\](.*?)\\[/color\\]")
		result = regex.sub(result, "[url=%s][color=#%s]$1[/color][/url]" % [clue_id, color.to_html(false)], true)
	return result


## Convertit le pseudo-HTML très simple utilisé dans les données "brutes"
## (dump de mails, etc.) vers le BBCode natif d'un RichTextLabel : <br>,
## <color=...>/</color>, <b></b>, <i></i>. Volontairement limité à ces 4 tags
## — ce n'est pas un parseur HTML général, juste ce que les fiches du jeu
## utilisent réellement.
##
## "indice" dans les données est un mot-clé sémantique ("passage indice mis
## en évidence"), pas un nom de couleur à garder tel quel — il pointe sur
## `highlight_color` pour ne changer cette teinte qu'à un seul endroit (voir
## palette.gd) plutôt que dans chaque fichier de données. Par défaut
## Palette.TEXT_HIGHLIGHT (fond sombre, le cas courant — mail, galerie) ; un
## appelant sur fond clair (bulles SMS pastel) passe TEXT_HIGHLIGHT_ON_LIGHT à
## la place (voir Palette.is_light()). "important" se résout dans le même
## liseré (taille + couleur, Palette.IMPORTANT_OUTLINE) partout, y compris sur
## fond clair ; `important_outline_size`/`important_outline_color` restent
## disponibles si un futur écran en a besoin, mais `important_text_color` est
## le seul écart actuellement utilisé (SMS fond clair, voir sms_section.gd) :
## force l'écriture en blanc au lieu du texte sombre hérité de la bulle pastel.
static func html_to_bbcode(text: String, highlight_color: Color = Palette.TEXT_HIGHLIGHT, important_outline_size: int = IMPORTANT_OUTLINE_SIZE, important_text_color: Color = Color.TRANSPARENT, important_outline_color: Color = Palette.IMPORTANT_OUTLINE) -> String:
	var result := text.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
	result = result.replace("<b>", "[b]").replace("</b>", "[/b]")
	result = result.replace("<i>", "[i]").replace("</i>", "[/i]")
	result = result.replace("<color=indice>", "[color=#%s]" % highlight_color.to_html(false))
	result = _outline_important(result, "<color=important>(.*?)</color>", important_outline_size, important_text_color, important_outline_color)
	var color_regex := RegEx.new()
	color_regex.compile("<color=([^>]+)>")
	result = color_regex.sub(result, "[color=$1]", true)
	result = result.replace("</color>", "[/color]")
	return result
