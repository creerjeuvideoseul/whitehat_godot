extends Control
class_name MailSection
## Section "Mail" du téléphone d'Alizée : liste des mails reçus à gauche
## (simple "Boîte de réception", plus d'onglets Reçus/Envoyés), contenu du
## mail sélectionné à droite. Les mails envoyés restent dans le JSON
## (isSentBox=1) mais ne sont plus listés ici — ils ne servent qu'à être cités
## en réponse (voir MailEntry.mail_previous_id). Générique par conception —
## seul `data_path` est spécifique à Alizée, une mission 2+ avec une autre
## boîte mail n'aura qu'à dupliquer cette scène et changer ce champ dans
## l'inspecteur, sans toucher au script.
##
## Occupe tout PhoneSectionHost (voir desktop.tscn) : pas de barre de titre
## déplaçable/réductible comme ChatWindow/OsintWindow, ce n'est pas une
## fenêtre du bureau mais le contenu d'un écran du téléphone, remplacé en bloc
## par desktop.gd dès qu'une autre icône du téléphone est pressée.
##
## Le bouton X ne détruit pas la scène lui-même : c'est desktop.gd qui décide
## ce que "fermer" veut dire pour PhoneSectionHost (revenir à l'écran d'accueil
## du téléphone), cette scène se contente de signaler la demande.

signal close_requested
## Émis pour demander l'affichage d'une "pensée du joueur" (voir player_thought.gd)
## — même signal/contrat que VaultSection, câblé génériquement par desktop.gd
## via has_signal("thought_requested").
signal thought_requested(text: String)
## Émis quand le joueur clique le bouton "important" révélé par la clé
## META_HACK_PC_MOTHER_KEY — desktop.gd décide ce qu'ouvrir veut dire (sa
## propre fenêtre dédiée), cette scène ne connaît que son propre bouton.
signal hack_pc_mother_requested

const PADLOCK_CLOSED := preload("res://assets/UI/padlock.png")
const PADLOCK_OPEN := preload("res://assets/UI/open-padlock.png")
const ATTACHMENT_VIEWER := preload("res://scenes/desktop/phone/sections/attachment_viewer.tscn")
const AVATAR_SIZE := Vector2(56, 56)
const ROW_GAP := 8
const FIELD_GAP := 10
## Ligne vierge avant le mail précédent cité en réponse (voir
## _build_quoted_previous_mail) — ROW_GAP seul (8px) collait trop les deux
## mails, retour joueur.
const QUOTED_MAIL_BLANK_LINE_HEIGHT := Palette.SIZE_BODY
## Ratio 16/9 plutôt que le ratio quasi carré des vignettes de la galerie —
## voir _build_attachment_thumbnail.
const ATTACHMENT_THUMB_WIDTH := 750.0
const ATTACHMENT_THUMB_HEIGHT := 422.0
## Même recette que le clignotement TOR du header (voir desktop_header.gd).
const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4
## Délai avant que le bouton PIRATER LE PC et la pensée du joueur n'apparaissent
## après le dépli des métadonnées — laisse le temps de lire les champs plutôt
## que de tout faire surgir d'un coup au clic sur MÉTADONNÉES.
const METADATA_REVEAL_DELAY_SECONDS := 1.0
## Deux clés réservées dans meta_info, gérées à part plutôt qu'affichées comme
## un champ générique — même esprit que les tags [#indice=xxx]/<indice id="...">
## ailleurs dans le projet : un mot-clé reconnu par le code plutôt qu'un
## nouveau rayon JSON séparé, pour ne pas casser la donnée déjà écrite par
## l'utilisateur dans alizee_mailbox.json.
const META_PLAYER_THINK_KEY := "Player_Think"
const META_HACK_PC_MOTHER_KEY := "Hack_PC_Mother"
## Préfixe de citation ajouté à chaque ligne du mail cité en réponse (voir
## MailEntry.mail_previous_id/_build_quoted_previous_mail) — convention
## universelle de citation de mail, pour bien montrer "reply to".
const QUOTE_PREFIX := "> "
## Fondu d'entrée/sortie de la musique d'un mail (voir MailEntry.play_music) —
## même valeur pour les deux, "fadeout 1" demandé explicitement pour la sortie.
const MAIL_MUSIC_FADE_SECONDS := 1.0

## Fichier JSON de la boîte mail affichée — voir MailDatabase. Le seul champ à
## changer pour réutiliser cette scène sur un autre personnage/mission.
@export var data_path: String = "res://data/alizee_mailbox.json"

@onready var _close_button: Button = %CloseButton
@onready var _mail_list: VBoxContainer = %MailList
@onready var _detail_root: VBoxContainer = %DetailRoot

var _database: MailDatabase
var _selected_mail_id: int = -1
var _mail_rows: Dictionary = {}
## Clignotement du bouton PIRATER LE PC une fois révélé (voir
## _start_hack_button_blink) — tué avant de libérer le bouton (voir
## _clear_detail_root) : sinon un Tween continuerait de cibler un Control déjà
## libéré au mail suivant.
var _hack_button_blink_tween: Tween
## Une seule pensée du joueur par mail ouvert, à l'affichage de ses
## métadonnées (dépliées par défaut désormais, voir _build_metadata_section) —
## remis à faux à chaque nouveau mail (voir _clear_detail_root). Variable
## d'instance plutôt que capturée par la lambda de _build_metadata_section :
## une lambda GDScript capture par valeur, pas par référence, la réassigner en
## son sein ne modifierait pas une variable locale extérieure.
var _metadata_think_shown: bool = false
## Vrai une fois le bouton PIRATER LE PC révélé pour de bon (après le délai,
## voir _reveal_hack_button_after_delay) — permet de le remontrer directement
## (sans redélai ni re-clignotement) si le joueur replie puis redéplie
## MÉTADONNÉES, plutôt que de le redéclencher à chaque repli/dépli. Remis à
## faux à chaque nouveau mail (voir _clear_detail_root).
var _hack_button_revealed: bool = false


func _ready() -> void:
	_database = MailDatabase.new(data_path)
	_close_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		close_requested.emit()
	)
	_rebuild_list()
	_show_no_selection()


## Seuls les mails reçus sont listés/parcourables ici — les mails envoyés
## restent dans alizee_mailbox.json (isSentBox=1) mais ne servent plus qu'à
## être cités en réponse (voir MailEntry.mail_previous_id/
## MailDatabase.get_mail_by_id), plus à être affichés dans une liste séparée.
func _rebuild_list() -> void:
	for child in _mail_list.get_children():
		child.queue_free()
	_mail_rows.clear()

	for mail: MailEntry in _database.get_mails(false):
		var row := _build_mail_row(mail)
		_mail_list.add_child(row)
		_mail_rows[mail.mail_id] = row


func _build_mail_row(mail: MailEntry) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_mail_row_gui_input.bind(mail))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.add_child(_build_row_avatar(mail))

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = mail.correspondent_name
	## Tronqué avec ellipse, même traitement que SmsSection._build_conversation_row
	## pour son name_label — sinon un nom d'expéditeur un peu long forçait toute
	## la colonne ListPanel à s'élargir au-delà de sa largeur fixe (398.8px,
	## voir mail_section.tscn), désynchronisant sa largeur réelle de celle de
	## la colonne SMS malgré une valeur identique dans les deux scènes.
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	name_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	info_box.add_child(name_label)

	var date_label := Label.new()
	date_label.text = PhoneTime.format_timestamp(mail.timestamp)
	date_label.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	date_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	info_box.add_child(date_label)

	var subject_label := Label.new()
	subject_label.text = _display_subject(mail)
	subject_label.clip_text = true
	subject_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subject_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	subject_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	info_box.add_child(subject_label)

	hbox.add_child(info_box)
	margin.add_child(hbox)
	row.add_child(margin)
	return row


## Avatar normal, sauf mail crypté : le cadenas prend sa place (fermé tant que
## le coffre n'est pas débloqué, ouvert ensuite — mais toujours affiché, pour
## qu'on garde une trace visuelle qu'il s'agissait d'un mail protégé).
func _build_row_avatar(mail: MailEntry) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(2)
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(10)
	style.content_margin_left = 7
	style.content_margin_right = 7
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = AVATAR_SIZE

	var rect := TextureRect.new()
	rect.custom_minimum_size = AVATAR_SIZE
	rect.texture = _resolve_row_texture(mail)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(rect)
	return frame


## Le vrai sujet reste caché tant que le mail est crypté et non déverrouillé —
## dans la liste comme dans le détail, on ne doit même pas savoir de quoi ça
## parle avant d'avoir ouvert le coffre.
func _display_subject(mail: MailEntry) -> String:
	if mail.is_crypted and not PhoneVault.is_unlocked():
		return tr("MAIL_ENCRYPTED_TITLE")
	return mail.subject


func _resolve_row_texture(mail: MailEntry) -> Texture2D:
	if mail.is_crypted:
		return PADLOCK_OPEN if PhoneVault.is_unlocked() else PADLOCK_CLOSED
	if not mail.avatar_path.is_empty() and ResourceLoader.exists(mail.avatar_path):
		return load(mail.avatar_path)
	return null


func _on_mail_row_gui_input(event: InputEvent, mail: MailEntry) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_select_mail(mail)


func _select_mail(mail: MailEntry) -> void:
	_set_row_selected(_selected_mail_id, false)
	_selected_mail_id = mail.mail_id
	_set_row_selected(_selected_mail_id, true)
	_show_mail(mail)


func _set_row_selected(mail_id: int, is_selected: bool) -> void:
	if not _mail_rows.has(mail_id):
		return
	var row: PanelContainer = _mail_rows[mail_id]
	if is_selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.BORDER_ACCENT.r, Palette.BORDER_ACCENT.g, Palette.BORDER_ACCENT.b, 0.15)
		style.set_corner_radius_all(6)
		row.add_theme_stylebox_override("panel", style)
	else:
		row.remove_theme_stylebox_override("panel")


func _clear_detail_root() -> void:
	if is_instance_valid(_hack_button_blink_tween):
		_hack_button_blink_tween.kill()
		_hack_button_blink_tween = null
	_metadata_think_shown = false
	_hack_button_revealed = false
	## Coupe la musique du mail qu'on quitte (voir MailEntry.play_music) — sans
	## effet si aucune n'était en cours (MusicPlayer.stop() se charge déjà de
	## ce cas). _show_mail() la relance juste après si le mail suivant en a une.
	MusicPlayer.stop(MAIL_MUSIC_FADE_SECONDS)
	for child in _detail_root.get_children():
		child.queue_free()


## Coupe la musique d'un mail encore en cours si la section entière disparaît
## (autre icône du téléphone, voir desktop.gd) — _clear_detail_root() ne
## tourne alors pas, le nœud est libéré directement par l'appelant.
func _exit_tree() -> void:
	MusicPlayer.stop(MAIL_MUSIC_FADE_SECONDS)


func _show_no_selection() -> void:
	_clear_detail_root()

	var label := Label.new()
	label.text = tr("MAIL_NO_SELECTION")
	label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	_detail_root.add_child(label)


func _show_mail(mail: MailEntry) -> void:
	_clear_detail_root()

	_detail_root.add_child(_build_detail_header(mail))
	_detail_root.add_child(_build_detail_sender_row(mail))
	_detail_root.add_child(_build_content_frame(mail))
	if not _is_mail_locked(mail):
		## Point de sauvegarde à l'ouverture d'un mail réel (envoyé ou reçu) —
		## jamais pour le texte de substitution d'un mail crypté encore
		## verrouillé (voir _build_content_frame).
		SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())
		## Musique de fond du mail (voir MailEntry.play_music) — même garde-fou
		## que le point de sauvegarde ci-dessus : jamais sur un mail encore
		## crypté/verrouillé, où il n'y a rien de réel à "mettre en ambiance".
		if not mail.play_music.is_empty() and ResourceLoader.exists(mail.play_music):
			MusicPlayer.play(load(mail.play_music), MAIL_MUSIC_FADE_SECONDS)
		## Pensée déclenchée à l'ouverture du mail lui-même (voir MailEntry.player_think) —
		## distincte de META_PLAYER_THINK_KEY dans meta_info, qui se déclenche au
		## dépli de MÉTADONNÉES (voir _build_metadata_section).
		if not mail.player_think.is_empty():
			thought_requested.emit(mail.player_think)
		## MÉTADONNÉES n'a rien à montrer tant que le mail est crypté et pas
		## encore déverrouillé (voir _is_mail_locked, même garde-fou) — sinon le
		## bouton apparaissait déjà, avant même d'avoir accès au contenu réel du
		## mail.
		if not mail.meta_info.is_empty():
			_detail_root.add_child(_build_metadata_section(mail))


func _is_mail_locked(mail: MailEntry) -> bool:
	return mail.is_crypted and not PhoneVault.is_unlocked()


func _build_detail_header(mail: MailEntry) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", FIELD_GAP)

	var title_label := Label.new()
	title_label.text = _display_subject(mail)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	title_label.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE)
	row.add_child(title_label)

	var date_label := Label.new()
	date_label.text = PhoneTime.format_full_datetime(mail.timestamp)
	date_label.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	date_label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	row.add_child(date_label)

	return row


func _build_detail_sender_row(mail: MailEntry) -> Control:
	var label := Label.new()
	var direction_key := "MAIL_TO_LABEL" if mail.is_sent_box else "MAIL_FROM_LABEL"
	label.text = "%s %s <%s>" % [tr(direction_key), mail.correspondent_name, mail.correspondent_address()]
	label.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	return label


## "Cadre distinct" bordé + scrollbar verticale si le contenu dépasse. Mail
## crypté et coffre pas encore débloqué : texte de substitution à la place du
## vrai contenu, comme demandé plutôt qu'un flou (pas d'infra de flou dans le
## projet aujourd'hui).
func _build_content_frame(mail: MailEntry) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.set_border_width_all(2)
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	if _is_mail_locked(mail):
		SfxPlayer.play(SfxPlayer.ACCESS_DENIED_SFX)
		var locked_label := _build_body_label(tr("VAULT_ENCRYPTED_PLACEHOLDER"))
		locked_label.add_theme_color_override("default_color", Palette.TEXT_LOCKED)
		scroll.add_child(locked_label)
	else:
		## Boîte intermédiaire (au lieu du corps directement dans le scroll) :
		## laisse ajouter la vignette de pièce jointe juste en dessous du texte,
		## dans le même cadre bordé — voir MailEntry.attach_image plus bas.
		var content_box := VBoxContainer.new()
		## Sans ça, la ScrollContainer laisse la boîte se réduire à la taille
		## minimale de son contenu au lieu de remplir toute la largeur du
		## cadre — le texte se retrouvait à faire un retour à la ligne bien
		## avant le bord (mur invisible), body_label avait ce flag mais pas
		## son nouveau parent.
		content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_box.add_theme_constant_override("separation", ROW_GAP)
		scroll.add_child(content_box)

		## Un seul RichTextLabel pour tout le corps — _build_body_label résout
		## et câble lui-même les éventuels <indice id> (voir plus bas).
		var body_label := _build_body_label(mail.html_content)
		content_box.add_child(body_label)

		if not mail.attach_image.is_empty():
			content_box.add_child(_build_attachment_thumbnail(mail))

		if mail.mail_previous_id >= 0:
			var previous: MailEntry = _database.get_mail_by_id(mail.mail_previous_id)
			if previous != null:
				content_box.add_child(_build_quoted_previous_mail(previous))

	return frame


## `raw_text` peut porter des <indice id> (corps de mail réel, citation) ou
## non (texte de substitution "verrouillé") — resolve_indice_tags n'a d'effet
## que sur les balises réellement présentes, donc un seul chemin pour les deux
## cas plutôt qu'un appelant qui pré-résout à la main.
func _build_body_label(raw_text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	var rebuild := func(hovered_id: String) -> void:
		label.text = RichTextMarkup.html_to_bbcode(RichTextMarkup.resolve_indice_tags(raw_text, Palette.TEXT_HIGHLIGHT, Palette.TEXT_CLUE_CLICKED, hovered_id))
	rebuild.call("")
	if raw_text.contains("<indice id="):
		RichTextMarkup.wire_indice_interactions(label, rebuild)
	return label


## Le mail cité en réponse (voir MailEntry.mail_previous_id), sous le corps du
## mail courant : une ligne vierge (les deux mails étaient trop collés avec le
## seul ROW_GAP de content_box), puis sa propre ligne "De/À"
## (_build_detail_sender_row, correcte quel que soit son sens puisqu'elle ne
## dépend que de `previous`) puis son corps préfixé de "> " ligne par ligne
## (voir _quote_lines), en gris plus sombre pour le distinguer visuellement du
## mail courant — même principe qu'une vraie citation de mail. Un seul
## niveau : même si `previous` a lui-même un mail_previous_id, il n'est
## jamais résolu ici, pour ne pas empiler des citations de citations.
func _build_quoted_previous_mail(previous: MailEntry) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", FIELD_GAP)

	var blank_line := Control.new()
	blank_line.custom_minimum_size = Vector2(0, QUOTED_MAIL_BLANK_LINE_HEIGHT)
	box.add_child(blank_line)

	box.add_child(_build_detail_sender_row(previous))

	var quoted_html := _quote_lines(previous.html_content)
	var quoted_label := _build_body_label(quoted_html)
	quoted_label.add_theme_color_override("default_color", Palette.CONSOLE_TEXT)
	box.add_child(quoted_label)

	return box


## Préfixe chaque ligne (séparée par <br>, comme le reste du pseudo-HTML de
## alizee_mailbox.json) d'un chevron "> " — convention universelle de citation
## de mail, voir _build_quoted_previous_mail.
func _quote_lines(html: String) -> String:
	var lines := html.split("<br>")
	for i in lines.size():
		lines[i] = QUOTE_PREFIX + lines[i]
	return "<br>".join(lines)


## Vignette 16/9 de MailEntry.attach_image, sous le corps du mail — fond blanc
## comme les vraies photos de la galerie (voir GallerySection._build_thumbnail_image),
## recadrée (STRETCH_KEEP_ASPECT_COVERED) plutôt que réduite avec des bandes
## vides. Cliquable pour l'agrandir (voir _open_attachment_viewer).
func _build_attachment_thumbnail(mail: MailEntry) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(ATTACHMENT_THUMB_WIDTH, ATTACHMENT_THUMB_HEIGHT)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.gui_input.connect(_on_attachment_gui_input.bind(mail))

	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists(mail.attach_image):
		rect.texture = load(mail.attach_image)
	frame.add_child(rect)
	return frame


func _on_attachment_gui_input(event: InputEvent, mail: MailEntry) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_open_attachment_viewer(mail)


## Reprend le chrome de GalleryDetail (fenêtre bordée, bouton "Retour" en
## haut qui ferme) plutôt qu'un simple fond assombri — voir AttachmentViewer.
## Jetable comme GalleryDetail : une instance par ouverture, libérée à la
## fermeture.
func _open_attachment_viewer(mail: MailEntry) -> void:
	var viewer: AttachmentViewer = ATTACHMENT_VIEWER.instantiate()
	viewer.closed.connect(func() -> void: viewer.queue_free())
	add_child(viewer)
	viewer.show_image(mail.attach_image, tr("MAIL_ATTACHMENT_VIEWER_TITLE"))


## Dépliée par défaut désormais (retour joueur) — le bouton "MÉTADONNÉES" ne
## clignote plus (rien à découvrir par un clic, déjà visible) mais reste
## cliquable pour replier/redéplier — libellé traduit via MAIL_METADATA_BUTTON
## (ui.csv), cohérent avec le même mot utilisé par RelayGhost dans
## relayghost_help.dialogue.
##
## META_PLAYER_THINK_KEY/META_HACK_PC_MOTHER_KEY sont exclues de la liste de
## champs générique : la première déclenche une pensée du joueur, la seconde
## ajoute un bouton "important" séparé plutôt que de s'afficher comme un champ
## de plus — toutes deux révélées après un court délai (voir
## METADATA_REVEAL_DELAY_SECONDS) dès la construction de cette section, plus
## au clic sur MÉTADONNÉES (qui n'a plus besoin d'être dépliée à la main pour
## ça).
func _build_metadata_section(mail: MailEntry) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_GAP)

	## Ligne d'en-tête horizontale : MÉTADONNÉES + (si présent) le bouton
	## PIRATER LE PC juste à côté, séparés de 50px. Le bouton hack reste
	## masqué jusqu'à sa révélation différée (voir plus bas), qu'il faille ou
	## non replier/redéplier MÉTADONNÉES entre-temps.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 50)
	box.add_child(header_row)

	var toggle_button := Button.new()
	toggle_button.text = tr("MAIL_METADATA_BUTTON")
	toggle_button.theme_type_variation = &"PrimaryButton"
	toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header_row.add_child(toggle_button)

	var hack_button: Button = null
	if bool(mail.meta_info.get(META_HACK_PC_MOTHER_KEY, false)):
		hack_button = Button.new()
		hack_button.text = tr("MAIL_HACK_PC_MOTHER_BUTTON")
		hack_button.theme_type_variation = &"ImportantButton"
		hack_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hack_button.visible = false
		hack_button.pressed.connect(func() -> void:
			SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
			if is_instance_valid(_hack_button_blink_tween):
				_hack_button_blink_tween.kill()
				_hack_button_blink_tween = null
			hack_button.modulate.a = 1.0
			hack_pc_mother_requested.emit()
		)
		header_row.add_child(hack_button)

	var fields_box := VBoxContainer.new()
	fields_box.visible = true
	fields_box.add_theme_constant_override("separation", 4)
	for key in mail.meta_info.keys():
		if key == META_PLAYER_THINK_KEY or key == META_HACK_PC_MOTHER_KEY:
			continue
		## RichTextLabel, pas Label : une valeur peut porter <color=important>
		## (voir Remote_Port dans alizee_mailbox.json), résolu comme partout
		## ailleurs via RichTextMarkup.html_to_bbcode.
		var field_label := RichTextLabel.new()
		field_label.bbcode_enabled = true
		field_label.selection_enabled = true
		field_label.fit_content = true
		field_label.scroll_active = false
		field_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field_label.add_theme_color_override("default_color", Palette.CONSOLE_TEXT)
		field_label.add_theme_font_size_override("normal_font_size", Palette.SIZE_SMALL)
		field_label.text = RichTextMarkup.html_to_bbcode("%s : %s" % [key, str(mail.meta_info[key])])
		fields_box.add_child(field_label)

	box.add_child(fields_box)

	## Replier/redéplier reste possible : le bouton hack suit (recaché à la
	## fermeture, remontré directement si déjà révélé — voir
	## _hack_button_revealed) sans redéclencher son délai à chaque repli.
	toggle_button.pressed.connect(func() -> void:
		fields_box.visible = not fields_box.visible
		if not is_instance_valid(hack_button):
			return
		if fields_box.visible:
			if _hack_button_revealed:
				hack_button.visible = true
		else:
			hack_button.visible = false
			if is_instance_valid(_hack_button_blink_tween):
				_hack_button_blink_tween.kill()
				_hack_button_blink_tween = null
	)

	if is_instance_valid(hack_button):
		_reveal_hack_button_after_delay(hack_button, fields_box)

	if not _metadata_think_shown:
		_metadata_think_shown = true
		var think_text: String = str(mail.meta_info.get(META_PLAYER_THINK_KEY, ""))
		if not think_text.is_empty():
			_reveal_metadata_thought_after_delay(fields_box, think_text)

	return box


## Laisse le joueur lire les métadonnées une seconde avant de faire surgir le
## bouton "important" — voir METADATA_REVEAL_DELAY_SECONDS. Vérifie que les
## métadonnées sont toujours dépliées à la fin de l'attente : si le joueur a
## refermé MÉTADONNÉES entre-temps (ou changé de mail, qui libère hack_button),
## la révélation est simplement annulée.
func _reveal_hack_button_after_delay(hack_button: Button, fields_box: Control) -> void:
	await get_tree().create_timer(METADATA_REVEAL_DELAY_SECONDS).timeout
	if not is_instance_valid(hack_button) or not is_instance_valid(fields_box) or not fields_box.visible:
		return
	hack_button.visible = true
	_hack_button_revealed = true
	_start_hack_button_blink(hack_button)


## Clignote tant que le joueur n'a pas cliqué le bouton — tué au clic (voir le
## connect de hack_button plus haut) ou à la fermeture des métadonnées.
func _start_hack_button_blink(hack_button: Button) -> void:
	if is_instance_valid(_hack_button_blink_tween):
		_hack_button_blink_tween.kill()
	_hack_button_blink_tween = create_tween()
	_hack_button_blink_tween.set_loops()
	_hack_button_blink_tween.set_trans(Tween.TRANS_SINE)
	_hack_button_blink_tween.tween_property(hack_button, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	_hack_button_blink_tween.tween_property(hack_button, "modulate:a", 1.0, BLINK_SECONDS)


## Même délai que _reveal_hack_button_after_delay, pour la pensée du joueur —
## voir METADATA_REVEAL_DELAY_SECONDS.
func _reveal_metadata_thought_after_delay(fields_box: Control, think_text: String) -> void:
	await get_tree().create_timer(METADATA_REVEAL_DELAY_SECONDS).timeout
	if not is_instance_valid(fields_box) or not fields_box.visible:
		return
	thought_requested.emit(think_text)
