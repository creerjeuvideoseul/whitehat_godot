extends Control
class_name MailSection
## Section "Mail" du téléphone d'Alizée : liste des mails (envoyés/reçus) à
## gauche, contenu du mail sélectionné à droite. Générique par conception —
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

const PADLOCK_CLOSED := preload("res://assets/UI/padlock.png")
const PADLOCK_OPEN := preload("res://assets/UI/open-padlock.png")
const AVATAR_SIZE := Vector2(56, 56)
const ROW_GAP := 8
const FIELD_GAP := 10
const DIMMED_TAB_MODULATE := Color(1, 1, 1, 0.5)

## Fichier JSON de la boîte mail affichée — voir MailDatabase. Le seul champ à
## changer pour réutiliser cette scène sur un autre personnage/mission.
@export var data_path: String = "res://data/alizee_mailbox.json"

@onready var _close_button: Button = %CloseButton
@onready var _sent_button: Button = %SentButton
@onready var _received_button: Button = %ReceivedButton
@onready var _mail_list: VBoxContainer = %MailList
@onready var _detail_root: VBoxContainer = %DetailRoot

var _database: MailDatabase
var _showing_sent: bool = false
var _selected_mail_id: int = -1
var _mail_rows: Dictionary = {}
var _reveal_tracker: IndiceRevealTracker


func _ready() -> void:
	_database = MailDatabase.new(data_path)
	_close_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		close_requested.emit()
	)
	_sent_button.pressed.connect(func() -> void: _select_tab(true))
	_received_button.pressed.connect(func() -> void: _select_tab(false))
	_select_tab(false)


func _select_tab(is_sent: bool) -> void:
	_showing_sent = is_sent
	_sent_button.modulate = Color.WHITE if is_sent else DIMMED_TAB_MODULATE
	_received_button.modulate = DIMMED_TAB_MODULATE if is_sent else Color.WHITE
	_selected_mail_id = -1
	_rebuild_list()
	_show_no_selection()


func _rebuild_list() -> void:
	for child in _mail_list.get_children():
		child.queue_free()
	_mail_rows.clear()

	for mail: MailEntry in _database.get_mails(_showing_sent):
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
	style.set_content_margin_all(0)
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


## Partagé par _show_no_selection/_show_mail : le tracker doit toujours être
## disposé AVANT de libérer les Control de _detail_root (dont le ScrollContainer
## qu'il surveille), sinon dispose() plante sur une instance déjà libérée au
## prochain affichage — bug constaté en changeant d'onglet (Reçus/Envoyés)
## juste avant de sélectionner un mail : _select_tab() appelait
## _show_no_selection() sans jamais disposer le tracker du mail précédent.
func _clear_detail_root() -> void:
	if _reveal_tracker != null:
		_reveal_tracker.dispose()
		_reveal_tracker = null
	for child in _detail_root.get_children():
		child.queue_free()


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
	## Une fois le cadre attaché à l'arbre (pas avant : ses Control n'ont pas
	## de position globale valide tant qu'ils sont détachés) — démarre la
	## surveillance (voir IndiceRevealTracker.start() : ne pas connecter ses
	## signaux avant que le contenu soit stable, sinon ils se déclenchent
	## pendant la construction elle-même).
	if _reveal_tracker != null:
		_reveal_tracker.start()

	if not mail.meta_info.is_empty():
		_detail_root.add_child(_build_metadata_section(mail))


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

	if mail.is_crypted and not PhoneVault.is_unlocked():
		SfxPlayer.play(SfxPlayer.ACCESS_DENIED_SFX)
		var locked_label := _build_body_label(tr("VAULT_ENCRYPTED_PLACEHOLDER"))
		locked_label.add_theme_color_override("default_color", Palette.TEXT_LOCKED)
		scroll.add_child(locked_label)
	else:
		## Un seul RichTextLabel pour tout le corps : le découper en segments
		## autour de <indice> (un Control par segment, pour que
		## IndiceRevealTracker sache lequel est visible) forçait un saut de
		## ligne à chaque frontière de balise, même en plein milieu d'une
		## phrase. L'indice se débloque donc dès que le corps entier est
		## visible, pas seulement le passage surligné — même grain que pour
		## une bulle SMS (voir sms_section.gd), pas une régression.
		_reveal_tracker = IndiceRevealTracker.new(scroll)
		var body_label := _build_body_label(RichTextMarkup.strip_indice_tags(mail.html_content))
		scroll.add_child(body_label)
		for clue_id in RichTextMarkup.extract_indice_ids(mail.html_content):
			_reveal_tracker.watch(body_label, clue_id)

	return frame


func _build_body_label(raw_text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	label.text = RichTextMarkup.html_to_bbcode(raw_text)
	return label


## Repliée par défaut, dépliée au clic sur le bouton "VIEW METADATA" — garde
## le libellé du bouton en anglais, dans le jargon technique volontairement
## non traduit du reste de l'interface (voir desktop.gd, _build_jean_dump_lines).
func _build_metadata_section(mail: MailEntry) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_GAP)

	var toggle_button := Button.new()
	toggle_button.text = "VIEW METADATA"
	toggle_button.theme_type_variation = &"PrimaryButton"
	toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(toggle_button)

	var fields_box := VBoxContainer.new()
	fields_box.visible = false
	fields_box.add_theme_constant_override("separation", 4)
	for key in mail.meta_info.keys():
		var field_label := Label.new()
		field_label.text = "%s : %s" % [key, str(mail.meta_info[key])]
		field_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field_label.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
		field_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
		fields_box.add_child(field_label)
	box.add_child(fields_box)

	toggle_button.pressed.connect(func() -> void: fields_box.visible = not fields_box.visible)
	return box
