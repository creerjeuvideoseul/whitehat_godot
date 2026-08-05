extends Control
class_name SmsSection
## Section "SMS" du téléphone d'Alizée : liste des conversations à gauche,
## fil de discussion à droite. Générique par conception, comme MailSection —
## seul `data_path` est spécifique à Alizée, une mission 2+ n'aura qu'à
## dupliquer cette scène et changer ce champ dans l'inspecteur.
##
## Pas de barre de titre déplaçable/réductible : ce n'est pas une fenêtre du
## bureau mais le contenu d'un écran du téléphone (voir MailSection pour
## l'explication complète du bouton X / close_requested).
##
## Contrairement à ChatWindow, tout s'affiche d'un coup (pas de typing) : ce
## sont des messages déjà envoyés qu'on consulte a posteriori (le "dump"),
## pas une conversation qui se déroule en direct.

signal close_requested

const PADLOCK_CLOSED := preload("res://assets/UI/padlock.png")
const PADLOCK_OPEN := preload("res://assets/UI/open-padlock.png")
const AVATAR_SIZE := Vector2(56, 56)
## Une bulle occupe toujours 2/3 de la largeur du fil (hauteur élastique,
## largeur fixe — voir _build_message_row) : ratio 2 pour la bulle contre 1
## pour l'espace vide qui la pousse à gauche ou à droite.
const BUBBLE_STRETCH_RATIO := 2.0
const SPACER_STRETCH_RATIO := 1.0
## Marge au-dessus de chaque message (bulle + timestamp), en plus de la
## séparation propre au timestamp — MessagesList n'a lui-même aucune
## séparation, cette marge est la seule source d'espacement entre messages.
const MESSAGE_TOP_MARGIN := 20

## Fichier JSON de la boîte SMS affichée — voir SmsDatabase. Le seul champ à
## changer pour réutiliser cette scène sur un autre personnage/mission.
@export var data_path: String = "res://data/alizee_smsbox.json"

@onready var _close_button: Button = %CloseButton
@onready var _conversation_list: VBoxContainer = %ConversationList
@onready var _messages_scroll: ScrollContainer = %MessagesScroll
@onready var _messages_list: VBoxContainer = %MessagesList

var _database: SmsDatabase
var _selected_conversation_id: int = -1
var _conversation_rows: Dictionary = {}


func _ready() -> void:
	_database = SmsDatabase.new(data_path)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_rebuild_conversation_list()
	_show_no_selection()


func _rebuild_conversation_list() -> void:
	for child in _conversation_list.get_children():
		child.queue_free()
	_conversation_rows.clear()

	for conv: SmsConversation in _database.get_conversations():
		var row := _build_conversation_row(conv)
		_conversation_list.add_child(row)
		_conversation_rows[conv.conversation_id] = row


func _build_conversation_row(conv: SmsConversation) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_conversation_row_gui_input.bind(conv))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.add_child(_build_row_avatar(conv))

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = conv.contact_name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	name_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	info_box.add_child(name_label)

	var count_label := Label.new()
	count_label.text = tr("SMS_MESSAGE_COUNT") % conv.messages.size()
	count_label.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	count_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	info_box.add_child(count_label)

	hbox.add_child(info_box)
	margin.add_child(hbox)
	row.add_child(margin)
	return row


## Avatar normal, sauf conversation cryptée : le cadenas prend sa place
## (fermé tant que le coffre n'est pas débloqué, ouvert ensuite) — même règle
## que MailSection._build_row_avatar.
func _build_row_avatar(conv: SmsConversation) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(2)
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = AVATAR_SIZE

	var rect := TextureRect.new()
	rect.custom_minimum_size = AVATAR_SIZE
	rect.texture = _resolve_row_texture(conv)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(rect)
	return frame


func _resolve_row_texture(conv: SmsConversation) -> Texture2D:
	if conv.is_crypted:
		return PADLOCK_OPEN if PhoneVault.is_unlocked() else PADLOCK_CLOSED
	if not conv.avatar_path.is_empty() and ResourceLoader.exists(conv.avatar_path):
		return load(conv.avatar_path)
	return null


func _on_conversation_row_gui_input(event: InputEvent, conv: SmsConversation) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_conversation(conv)


func _select_conversation(conv: SmsConversation) -> void:
	_set_row_selected(_selected_conversation_id, false)
	_selected_conversation_id = conv.conversation_id
	_set_row_selected(_selected_conversation_id, true)
	_show_conversation(conv)


func _set_row_selected(conversation_id: int, is_selected: bool) -> void:
	if not _conversation_rows.has(conversation_id):
		return
	var row: PanelContainer = _conversation_rows[conversation_id]
	if is_selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.BORDER_ACCENT.r, Palette.BORDER_ACCENT.g, Palette.BORDER_ACCENT.b, 0.15)
		style.set_corner_radius_all(6)
		row.add_theme_stylebox_override("panel", style)
	else:
		row.remove_theme_stylebox_override("panel")


func _show_no_selection() -> void:
	for child in _messages_list.get_children():
		child.queue_free()

	var label := Label.new()
	label.text = tr("SMS_NO_SELECTION")
	label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	_messages_list.add_child(label)


## Conversation cryptée et coffre pas encore débloqué : un seul texte de
## substitution remplace tout le fil (pas de flou, comme pour Mail — voir
## PhoneVault). Sinon, une bulle par message, puis on cale le scroll tout en
## bas : "on voit toujours le dernier message d'une conversation SMS."
func _show_conversation(conv: SmsConversation) -> void:
	for child in _messages_list.get_children():
		child.queue_free()

	if conv.is_crypted and not PhoneVault.is_unlocked():
		var label := Label.new()
		label.text = tr("VAULT_ENCRYPTED_PLACEHOLDER")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
		label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
		_messages_list.add_child(label)
	else:
		for entry: SmsEntry in conv.messages:
			_messages_list.add_child(_build_message_row(entry, conv))

	_scroll_to_bottom()


## Une ligne pleine largeur, avec 20px de marge au-dessus (MESSAGE_TOP_MARGIN) ;
## la colonne bulle+timestamp occupe 2/3 de cette largeur, poussée à gauche
## (contact) ou à droite (Alizée) par un espaceur du côté opposé — voir
## BUBBLE_STRETCH_RATIO/SPACER_STRETCH_RATIO.
func _build_message_row(entry: SmsEntry, conv: SmsConversation) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", MESSAGE_TOP_MARGIN)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var column := _build_message_column(entry, conv)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = SPACER_STRETCH_RATIO

	if entry.is_answer:
		row.add_child(spacer)
		row.add_child(column)
	else:
		row.add_child(column)
		row.add_child(spacer)

	margin.add_child(row)
	return margin


## La bulle, puis le timestamp juste en dessous mais HORS du rectangle —
## aligné du même côté que la bulle (à droite pour Alizée, à gauche sinon).
## Toujours en Palette.CONSOLE_TEXT, jamais colorFont : colorFont n'est lisible
## que sur le fond clair de la bulle (colorBackground), pas sur le fond sombre
## de l'app une fois le timestamp sorti du rectangle.
func _build_message_column(entry: SmsEntry, conv: SmsConversation) -> Control:
	var font_color := Palette.TEXT_NORMAL if entry.is_answer else conv.color_font

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = BUBBLE_STRETCH_RATIO
	column.add_theme_constant_override("separation", 4)
	column.add_child(_build_bubble(entry, conv, font_color))

	var timestamp := Label.new()
	timestamp.text = PhoneTime.format_timestamp(entry.timestamp)
	timestamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if entry.is_answer else HORIZONTAL_ALIGNMENT_LEFT
	timestamp.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	timestamp.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	column.add_child(timestamp)

	return column


## Le texte des messages à droite (Alizée) est lui-même aligné à droite dans
## sa bulle — via [right], seul moyen d'aligner un RichTextLabel (pas de
## propriété d'alignement directe comme sur Label).
func _build_bubble(entry: SmsEntry, conv: SmsConversation, font_color: Color) -> Control:
	var bg_color := Palette.BUBBLE_PLAYER if entry.is_answer else conv.color_background

	var bubble := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", style)

	var message := RichTextLabel.new()
	message.bbcode_enabled = true
	message.fit_content = true
	message.scroll_active = false
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("default_color", font_color)
	message.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	var resolved := RichTextMarkup.resolve_indice_tags(entry.message)
	var bbcode := RichTextMarkup.html_to_bbcode(resolved)
	message.text = "[right]%s[/right]" % bbcode if entry.is_answer else bbcode
	bubble.add_child(message)

	return bubble


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_messages_scroll.scroll_vertical = int(_messages_scroll.get_v_scroll_bar().max_value)
