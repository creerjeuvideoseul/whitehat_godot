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

@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _document_list: VBoxContainer = %DocumentList
@onready var _detail_root: VBoxContainer = %DetailRoot

var _database: ChristineDocumentDatabase
## document_id -> PanelContainer, pour appliquer/retirer le style "sélectionné"
## sans reconstruire toute la liste — même principe que MailSection._mail_rows.
var _document_rows: Dictionary = {}
var _selected_document_id: int = -1


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
	return row


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

	_detail_root.add_child(_build_content_frame(document))
	## ClueManager.unlock() n'écrit rien sur disque tout seul (déclenché par un
	## clic sur le texte, voir _build_body_label) — un checkpoint explicite à
	## l'ouverture du document reste nécessaire pour ne pas perdre la
	## progression si le joueur quitte juste après.
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())


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
