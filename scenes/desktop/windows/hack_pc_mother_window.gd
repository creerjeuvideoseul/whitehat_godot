extends Control
class_name HackPcMotherWindow
## Fenêtre "Piratage — PC de la mère", déclenchée après validation du mot de
## passe RDP de Christine (voir desktop.gd, _on_hack_pc_mother_login_succeeded) —
## même chrome que ClueBoardWindow/OsintWindow (titre, réduction, bordure vive).
## Liste des documents trouvés sur son PC à gauche, contenu du document
## sélectionné à droite — même schéma liste/détail que MailSection, en plus
## simple (un seul jeu de documents figé, pas d'onglets envoyés/reçus).

signal minimize_requested(window: Control, window_title: String)

const DOC_ICON := preload("res://assets/UI/doc.png")
const ICON_SIZE := Vector2(40, 40)
## Vignette du certificat scanné (voir _build_content_frame) — proche du ratio
## réel de certificat_justice.png (705×712, quasi carré).
const ATTACHED_IMAGE_SIZE := Vector2(360, 364)
## Bordure de survol d'une ligne de document — même recette que
## GallerySection._style_hover_border (calque séparé plutôt qu'un style posé
## sur `row` lui-même, qui porte déjà le fond de sélection via _set_row_selected).
const ROW_HOVER_BORDER_WIDTH := 3
const ROW_HOVER_CORNER_RADIUS := 6

## "Révélation par redaction" à la première ouverture d'un document : le corps
## est d'abord couvert de bandes noires façon dossier classifié, qui se
## retirent l'une après l'autre du haut vers le bas — ces documents viennent
## d'être piratés, l'effet vend l'idée qu'on "déclassifie" ce qu'on vient de
## trouver plutôt que d'afficher un texte déjà connu. Une seule fois par
## document (voir _redacted_document_ids) : le rouvrir ensuite l'affiche
## directement, comme un document qu'on a déjà lu.
const REDACTION_BAND_COUNT := 8
const REDACTION_BAND_DELAY_SECONDS := 0.12
const REDACTION_BAND_FADE_SECONDS := 0.25
## Petite pause avant que la première bande ne se retire, pour laisser
## l'œil se poser sur le document encore entièrement couvert.
const REDACTION_START_DELAY_SECONDS := 0.3
## Fondu d'entrée à chaque changement de document sélectionné — voir
## _show_document.
const DETAIL_FADE_SECONDS := 0.2

@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _document_list: VBoxContainer = %DocumentList
@onready var _detail_root: VBoxContainer = %DetailRoot

var _database: ChristineDocumentDatabase
## document_id -> PanelContainer, pour appliquer/retirer le style "sélectionné"
## sans reconstruire toute la liste — même principe que MailSection._mail_rows.
var _document_rows: Dictionary = {}
var _selected_document_id: int = -1
## document_id déjà "déclassifiés" une première fois (voir REDACTION_BAND_COUNT) —
## une instance par ouverture de la fenêtre (pas de persistance entre deux
## piratages, il n'y en a qu'un dans cette mission), pour ne jouer l'effet
## qu'à la toute première lecture de chaque document.
var _redacted_document_ids: Dictionary = {}


func _ready() -> void:
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_database = ChristineDocumentDatabase.new()
	_rebuild_list()


func _on_minimize_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
	minimize_requested.emit(self, _title_label.text)


## Premier document sélectionné d'office : contrairement à la boîte mail, il
## n'y a que 3 documents fixes et pas d'historique à parcourir — l'utilité de
## cette fenêtre, c'est justement de lire tout de suite ce qui vient d'être
## trouvé, pas de cliquer une première fois pour sortir d'un écran vide.
func _rebuild_list() -> void:
	for child in _document_list.get_children():
		child.queue_free()
	_document_rows.clear()

	var documents := _database.get_documents()
	for document in documents:
		var row := _build_document_row(document)
		_document_list.add_child(row)
		_document_rows[document.document_id] = row

	if not documents.is_empty():
		_select_document(documents[0])


func _build_document_row(document: ChristineDocumentEntry) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_document_row_gui_input.bind(document))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = DOC_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hbox.add_child(icon)

	var title_label := Label.new()
	title_label.text = document.title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	title_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	hbox.add_child(title_label)

	margin.add_child(hbox)
	row.add_child(margin)

	# Calque posé APRÈS margin pour se dessiner par-dessus — voir
	# GallerySection._build_thumbnail pour la même contrainte de calque.
	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_row_hover_border(border, false)
	row.add_child(border)
	row.mouse_entered.connect(func() -> void: _style_row_hover_border(border, true))
	row.mouse_exited.connect(func() -> void: _style_row_hover_border(border, false))

	return row


## Même mécanisme que GallerySection._style_hover_border, dupliqué ici plutôt
## que partagé — petit effet d'interface propre à cet écran (voir
## feedback_architecture_principles).
func _style_row_hover_border(border: Panel, is_hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(ROW_HOVER_BORDER_WIDTH if is_hovered else 0)
	style.border_color = Palette.TEXT_ACCENT
	style.set_corner_radius_all(ROW_HOVER_CORNER_RADIUS)
	style.set_content_margin_all(0)
	border.add_theme_stylebox_override("panel", style)


func _on_document_row_gui_input(event: InputEvent, document: ChristineDocumentEntry) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_select_document(document)


func _select_document(document: ChristineDocumentEntry) -> void:
	_set_row_selected(_selected_document_id, false)
	_selected_document_id = document.document_id
	_set_row_selected(_selected_document_id, true)
	_show_document(document)


func _set_row_selected(document_id: int, is_selected: bool) -> void:
	if not _document_rows.has(document_id):
		return
	var row: PanelContainer = _document_rows[document_id]
	if is_selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.BORDER_ACCENT.r, Palette.BORDER_ACCENT.g, Palette.BORDER_ACCENT.b, 0.15)
		style.set_corner_radius_all(6)
		row.add_theme_stylebox_override("panel", style)
	else:
		row.remove_theme_stylebox_override("panel")


func _show_document(document: ChristineDocumentEntry) -> void:
	for child in _detail_root.get_children():
		child.queue_free()

	var title_label := Label.new()
	title_label.text = document.title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	title_label.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE)
	_detail_root.add_child(title_label)

	var frame := _build_content_frame(document)
	_detail_root.add_child(frame)
	if not _redacted_document_ids.has(document.document_id):
		_redacted_document_ids[document.document_id] = true
		_reveal_with_redaction(frame)

	## ClueManager.unlock() n'écrit rien sur disque tout seul (déclenché par un
	## clic sur le texte, voir _build_body_label) — un checkpoint explicite à
	## l'ouverture du document reste nécessaire pour ne pas perdre la
	## progression si le joueur quitte juste après.
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())

	## Fondu d'entrée à chaque changement de document — sinon le detail se
	## reconstruit d'un coup (queue_free puis rebuild synchrone), même esprit
	## que desktop.gd::PHONE_SECTION_FADE_SECONDS pour les sections du téléphone.
	_detail_root.modulate.a = 0.0
	var reveal_tween := create_tween()
	reveal_tween.tween_property(_detail_root, "modulate:a", 1.0, DETAIL_FADE_SECONDS)


## Couvre le cadre de bandes noires façon dossier classifié, qui se retirent
## une à une du haut vers le bas — uniquement à la première ouverture de CE
## document (voir _redacted_document_ids dans _show_document), pour vendre
## l'idée qu'on "déclassifie" ce qui vient d'être piraté plutôt que d'afficher
## un texte déjà connu d'un coup.
##
## `frame` est un PanelContainer (voir _build_content_frame) : lui ajouter cet
## overlay en second enfant suffit à le faire occuper exactement le même
## rectangle que `scroll`, sans code de positionnement manuel — même
## mécanisme que GallerySection._build_thumbnail pour sa bordure de survol.
func _reveal_with_redaction(frame: Control) -> void:
	var overlay := VBoxContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_constant_override("separation", 0)
	for i in REDACTION_BAND_COUNT:
		var band := ColorRect.new()
		band.color = Color.BLACK
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.size_flags_vertical = Control.SIZE_EXPAND_FILL
		overlay.add_child(band)
	frame.add_child(overlay)

	await get_tree().create_timer(REDACTION_START_DELAY_SECONDS).timeout
	if not is_instance_valid(overlay):
		return
	for band in overlay.get_children():
		if is_instance_valid(band):
			var tween := create_tween()
			tween.tween_property(band, "modulate:a", 0.0, REDACTION_BAND_FADE_SECONDS)
		await get_tree().create_timer(REDACTION_BAND_DELAY_SECONDS).timeout
		if not is_instance_valid(overlay):
			return
	overlay.queue_free()


## Cadre bordé + scrollbar verticale si le contenu dépasse — même recette que
## MailSection._build_content_frame, sans le cas "encore crypté" (rien n'est
## verrouillé ici, ces documents viennent d'être déchiffrés par le terminal).
func _build_content_frame(document: ChristineDocumentEntry) -> Control:
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

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	var body_label := _build_body_label(document.content)
	body.add_child(body_label)

	## Certificat scanné joint au document (voir ChristineDocumentEntry.image) —
	## affiché sous le texte, en vignette bordée façon pièce jointe plutôt
	## qu'étiré à la largeur du cadre (EXPAND_FIT_WIDTH_PROPORTIONAL laissait
	## une hauteur nulle dans ce VBoxContainer : une taille fixe garantit qu'il
	## reste visible quelle que soit la largeur du panneau).
	if not document.image.is_empty() and ResourceLoader.exists(document.image):
		var image_frame := PanelContainer.new()
		image_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var image_style := StyleBoxFlat.new()
		image_style.set_border_width_all(2)
		image_style.border_color = Palette.BORDER_ACCENT
		image_style.content_margin_left = 6
		image_style.content_margin_top = 6
		image_style.content_margin_right = 6
		image_style.content_margin_bottom = 6
		image_frame.add_theme_stylebox_override("panel", image_style)

		var image_rect := TextureRect.new()
		image_rect.texture = load(document.image)
		image_rect.custom_minimum_size = ATTACHED_IMAGE_SIZE
		image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_frame.add_child(image_rect)

		body.add_child(image_frame)

	return frame


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
