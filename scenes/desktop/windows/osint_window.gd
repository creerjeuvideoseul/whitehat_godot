extends Control
class_name OsintWindow
## Fenêtre "Recherche OSINT" : même chrome (fond/cadre vert, barre de titre,
## réduction, déplacement) que ChatWindow, mais un contenu unique — la fiche
## du personnage trouvé — plutôt qu'une liste de contacts. Entièrement
## reconstruite à chaque recherche (search()), jamais accumulée : "chercher
## un pseudo efface l'ancien contenu de la fenêtre OSINT."

signal minimize_requested(window: Control, window_title: String)

const AVATAR_WIDTH := 200.0
const AVATAR_HEIGHT := 200.0
const HEADER_GAP := 24
const FIELD_GAP := 10
const SECTION_GAP := 24
## Largeur fixe de la colonne "clé" d'une ligne champ/valeur, pour que toutes
## les valeurs démarrent alignées quelle que soit la longueur du libellé.
const LABEL_COLUMN_WIDTH := 280.0

@onready var _title_bar: PanelContainer = %TitleBar
@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _content_root: VBoxContainer = %ContentRoot

var _dragging: bool = false
var _database: OsintDatabase = OsintDatabase.new()


func _ready() -> void:
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_title_bar.gui_input.connect(_on_title_bar_gui_input)


## Lance (ou relance) une recherche : vide entièrement le contenu précédent,
## puis affiche la fiche trouvée ou un message "aucun résultat".
func search(query: String) -> void:
	for child in _content_root.get_children():
		child.queue_free()

	var character := _database.search(query)
	if character.is_empty():
		_build_no_result()
	else:
		_build_profile(character)


## Comme ChatWindow.nudge_position : décale la fenêtre sans jamais la sortir
## du bureau.
func nudge_position(offset: Vector2) -> void:
	var max_position: Vector2 = get_parent_area_size() - size
	position = (position + offset).clamp(Vector2.ZERO, max_position)


## Glisser par la barre de titre, comme ChatWindow.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var max_position: Vector2 = get_parent_area_size() - size
		position = (position + event.relative).clamp(Vector2.ZERO, max_position)


func _on_minimize_pressed() -> void:
	hide()
	minimize_requested.emit(self, _title_label.text)


func _build_no_result() -> void:
	var label := Label.new()
	label.text = tr("OSINT_NO_RESULT")
	label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	_content_root.add_child(label)


## Photo + identité (Nom/Prénom/Age/Lieu de naissance/Statut) en haut, puis
## tous les autres champs présents dans la fiche, ligne par ligne dans l'ordre
## du JSON, puis la note personnelle tout en bas — voir OsintDatabase pour
## quels champs sont "réservés" au bloc du haut selon la langue active.
func _build_profile(character: Dictionary) -> void:
	var keys := _database.header_keys()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", HEADER_GAP)
	header.add_child(_build_photo(str(character.get(keys["photo"], ""))))
	header.add_child(_build_identity_block(character, keys))
	_content_root.add_child(header)

	var reserved: Array = [keys["name"], keys["first_name"], keys["age"], keys["birthplace"], keys["status"], keys["note"], keys["photo"], "characterId"]
	var fields_box := VBoxContainer.new()
	fields_box.add_theme_constant_override("separation", FIELD_GAP)
	for key in character.keys():
		if reserved.has(key):
			continue
		var value: String = str(character[key])
		if value.is_empty():
			continue
		fields_box.add_child(_build_field_row(key, value))
	if fields_box.get_child_count() > 0:
		_content_root.add_child(_wrap_with_top_margin(fields_box))

	var note: String = str(character.get(keys["note"], ""))
	if not note.is_empty():
		_content_root.add_child(_wrap_with_top_margin(_build_note_section(note)))


func _wrap_with_top_margin(child: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", SECTION_GAP)
	margin.add_child(child)
	return margin


func _build_photo(path: String) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.set_border_width_all(2)
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(AVATAR_WIDTH, AVATAR_HEIGHT)

	var texture: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(AVATAR_WIDTH, AVATAR_HEIGHT)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(rect)
	return frame


func _build_identity_block(character: Dictionary, keys: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", FIELD_GAP)

	var full_name := "%s %s" % [str(character.get(keys["first_name"], "")), str(character.get(keys["name"], ""))]
	var name_label := Label.new()
	name_label.text = full_name.strip_edges()
	name_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	name_label.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE + 5)
	box.add_child(name_label)

	for key in [keys["age"], keys["birthplace"], keys["status"]]:
		var value: String = str(character.get(key, ""))
		if value.is_empty():
			continue
		box.add_child(_build_field_row(key, value))

	return box


## Clé à largeur fixe (LABEL_COLUMN_WIDTH) + valeur qui prend le reste de la
## ligne — pour que toutes les valeurs d'une fiche démarrent alignées sur la
## même colonne, quelle que soit la longueur du libellé.
func _build_field_row(label: String, raw_value: String) -> Control:
	var value := RichTextMarkup.resolve_indice_tags(raw_value)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var key_label := Label.new()
	key_label.text = "%s :" % label
	key_label.custom_minimum_size = Vector2(LABEL_COLUMN_WIDTH, 0)
	key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	key_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	key_label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	row.add_child(key_label)

	var value_rich := RichTextLabel.new()
	value_rich.bbcode_enabled = true
	value_rich.fit_content = true
	value_rich.scroll_active = false
	value_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_rich.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	value_rich.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	value_rich.text = value
	row.add_child(value_rich)

	return row


## Une ligne vide au-dessus de la note personnelle, en plus de la marge de
## section déjà appliquée par _wrap_with_top_margin — pour bien la détacher
## du reste de la fiche, comme un paragraphe à part.
func _build_note_section(raw_note: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var blank_line := Control.new()
	blank_line.custom_minimum_size = Vector2(0, Palette.SIZE_BODY)
	box.add_child(blank_line)

	box.add_child(_build_note(raw_note))
	return box


func _build_note(raw_note: String) -> RichTextLabel:
	var note := RichTextMarkup.resolve_indice_tags(raw_note)

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_color_override("default_color", Palette.CONSOLE_TEXT)
	rich.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	rich.text = "[i]%s[/i]" % note
	return rich
