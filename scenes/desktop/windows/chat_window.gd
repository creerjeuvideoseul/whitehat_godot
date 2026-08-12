extends Control
class_name ChatWindow
## A reusable "encrypted chat" window: a contacts sidebar shared by several
## conversations (one ConversationView per contact, only one visible at a
## time). Built for AnonGhost + Jean Ranoud first, meant to be reused as-is
## for future contacts by just adding to `contacts`.
##
## No close button by design: minimizing is the only way to dismiss it (see
## minimize_requested), matching "on ne peut pas fermer la fenêtre, juste la
## réduire."
##
## A conversation only starts (and its dialogue only advances) once the
## player actually selects that contact — two contacts never play out
## simultaneously in the background just because the window is open.

signal minimize_requested(window: Control, window_title: String)
## Bubbled up from whichever ConversationView just finished, so the owner
## (desktop.gd) can react — e.g. reveal a contact that was waiting on it —
## without this window knowing anything about that narrative sequencing.
signal contact_conversation_finished(contact_id: String)

const CONVERSATION_VIEW := preload("res://scenes/desktop/windows/conversation_view.tscn")
const CHOICE_SOUND := preload("res://assets/audio/sound/mixkit-correct-answer-notification-947.mp3")
const NOTIFICATION_SOUND := preload("res://assets/audio/sound/soundreality-notification-30-313553.mp3")
const SHAKE_AMPLITUDE := 6.0
const SHAKE_STEP_SECONDS := 0.05
const SHAKE_STEPS := 6
## Même valeurs que le clignotement TOR du header (voir desktop_header.gd),
## pour rester cohérent visuellement.
const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4

@export var contacts: Array[ChatContact] = []

## Window chrome color scheme — as opposed to per-message bubble colors
## (ChatContact.bubble_color), which distinguish contacts from each other
## inside the same window.
@export var window_bg_color: Color = Palette.WINDOW_BG
@export var window_header_bg_color: Color = Palette.WINDOW_HEADER_BG
@export var accent_color: Color = Palette.BORDER_ACCENT

@onready var _background: Panel = %Background
@onready var _title_bar: PanelContainer = %TitleBar
@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _sidebar: PanelContainer = %Sidebar
@onready var _contacts_list: VBoxContainer = %ContactsList
@onready var _conversation_host: Control = %ConversationHost
@onready var _border_overlay: Panel = %BorderOverlay

var _dragging: bool = false
var _contacts_by_id: Dictionary = {}
var _conversation_views: Dictionary = {}
var _contact_rows: Dictionary = {}
var _started_contact_ids: Dictionary = {}
var _active_contact_id: String = ""
## contact_id -> Tween, tant que sa ligne clignote (voir _start_row_blink).
var _blink_tweens: Dictionary = {}


func _ready() -> void:
	_apply_color_scheme()
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_title_bar.gui_input.connect(_on_title_bar_gui_input)

	var initial_contacts := contacts.duplicate()
	for contact in initial_contacts:
		add_contact(contact)

	if initial_contacts.size() > 0:
		_select_contact(initial_contacts[0].contact_id)


## Add a contact to the sidebar — for the window's initial roster, or one
## that only "unlocks" later (e.g. once another conversation finishes).
## Either way it plays like an incoming message just arrived.
func add_contact(contact: ChatContact) -> void:
	_contacts_by_id[contact.contact_id] = contact
	_add_contact_row(contact)
	_build_conversation_view(contact)
	# Une conversation déjà terminée (reprise de sauvegarde, voir desktop.gd)
	# n'est pas un nouveau message qui vient d'arriver — seul un contact qui
	# apparaît vraiment pour la première fois pendant la session (AnonGhost au
	# tout début, Jean une fois AnonGhost fini) mérite le son + la secousse
	# + le clignotement de sa ligne tant qu'on n'a pas cliqué dessus.
	if not SaveManager.is_conversation_complete(contact.contact_id):
		_notify_new_message()
		_start_row_blink(contact.contact_id)


## Nudge the window from its default centered position (e.g. so several
## windows opened at once "cascade" instead of fully overlapping), clamped
## to stay on the desktop just like dragging does.
func nudge_position(offset: Vector2) -> void:
	var max_position: Vector2 = get_parent_area_size() - size
	position = (position + offset).clamp(Vector2.ZERO, max_position)


func _apply_color_scheme() -> void:
	var bg_style: StyleBoxFlat = _background.get_theme_stylebox("panel").duplicate()
	bg_style.bg_color = window_bg_color
	bg_style.border_color = accent_color
	_background.add_theme_stylebox_override("panel", bg_style)

	var titlebar_style: StyleBoxFlat = _title_bar.get_theme_stylebox("panel").duplicate()
	titlebar_style.bg_color = window_header_bg_color
	titlebar_style.border_color = accent_color
	_title_bar.add_theme_stylebox_override("panel", titlebar_style)

	var sidebar_style: StyleBoxFlat = _sidebar.get_theme_stylebox("panel").duplicate()
	sidebar_style.bg_color = window_header_bg_color
	_sidebar.add_theme_stylebox_override("panel", sidebar_style)

	var border_style: StyleBoxFlat = _border_overlay.get_theme_stylebox("panel").duplicate()
	border_style.border_color = accent_color
	_border_overlay.add_theme_stylebox_override("panel", border_style)


## Drag by the title bar only (like a real OS window), clamped so the
## window can't be dragged past the desktop's edges. MinimizeButton still
## gets its own clicks first — Buttons consume input before it reaches here.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var max_position: Vector2 = get_parent_area_size() - size
		position = (position + event.relative).clamp(Vector2.ZERO, max_position)


func _add_contact_row(contact: ChatContact) -> void:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_contact_row_gui_input.bind(contact.contact_id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.add_child(_build_avatar_frame(contact.avatar))

	var name_label := Label.new()
	name_label.text = contact.contact_name
	name_label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	name_label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	hbox.add_child(name_label)

	margin.add_child(hbox)
	row.add_child(margin)

	_contacts_list.add_child(row)
	_contact_rows[contact.contact_id] = row


func _build_avatar_frame(avatar: Texture2D) -> Control:
	var avatar_frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_width_left = 3
	frame_style.border_width_top = 3
	frame_style.border_width_right = 3
	frame_style.border_width_bottom = 3
	frame_style.border_color = accent_color
	frame_style.set_corner_radius_all(25)
	frame_style.set_content_margin_all(0)
	avatar_frame.add_theme_stylebox_override("panel", frame_style)

	var avatar_rect := TextureRect.new()
	avatar_rect.custom_minimum_size = Vector2(50, 50)
	avatar_rect.texture = avatar
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	avatar_frame.add_child(avatar_rect)
	return avatar_frame


func _build_conversation_view(contact: ChatContact) -> void:
	var view: ConversationView = CONVERSATION_VIEW.instantiate()
	view.visible = false
	view.choice_shown.connect(func() -> void: SfxPlayer.play(CHOICE_SOUND))
	view.conversation_finished.connect(func() -> void: contact_conversation_finished.emit(contact.contact_id))
	_conversation_host.add_child(view)
	_conversation_views[contact.contact_id] = view


## Sound + a light shake, like an incoming-message alert — used both when a
## contact first appears in the sidebar and (via add_contact) later on.
func _notify_new_message() -> void:
	SfxPlayer.play(NOTIFICATION_SOUND)
	_shake()


func _shake() -> void:
	var origin := position
	var tween := create_tween()
	for i in SHAKE_STEPS:
		var offset := Vector2(randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE), randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE))
		tween.tween_property(self, "position", origin + offset, SHAKE_STEP_SECONDS)
	tween.tween_property(self, "position", origin, SHAKE_STEP_SECONDS)


## Fait clignoter la ligne d'un contact (alpha, comme le TOR du header) tant
## qu'on n'a pas cliqué dessus — voir _stop_row_blink dans _select_contact.
func _start_row_blink(contact_id: String) -> void:
	var row: PanelContainer = _contact_rows.get(contact_id)
	if row == null:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(row, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	tween.tween_property(row, "modulate:a", 1.0, BLINK_SECONDS)
	_blink_tweens[contact_id] = tween


func _stop_row_blink(contact_id: String) -> void:
	if not _blink_tweens.has(contact_id):
		return
	var tween: Tween = _blink_tweens[contact_id]
	if is_instance_valid(tween):
		tween.kill()
	_blink_tweens.erase(contact_id)
	var row: PanelContainer = _contact_rows.get(contact_id)
	if row != null:
		row.modulate.a = 1.0


func _on_contact_row_gui_input(event: InputEvent, contact_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_select_contact(contact_id)


## Switch the visible conversation. The newly selected contact's dialogue
## only starts playing the first time it's selected — never before.
func _select_contact(contact_id: String) -> void:
	if _active_contact_id == contact_id:
		return
	_stop_row_blink(contact_id)

	if _conversation_views.has(_active_contact_id):
		_conversation_views[_active_contact_id].hide()
	_set_row_selected(_active_contact_id, false)

	_active_contact_id = contact_id
	var view: ConversationView = _conversation_views[contact_id]
	view.show()
	_set_row_selected(contact_id, true)

	if not _started_contact_ids.has(contact_id):
		_started_contact_ids[contact_id] = true
		view.setup(_contacts_by_id[contact_id])


func _set_row_selected(contact_id: String, is_selected: bool) -> void:
	if not _contact_rows.has(contact_id):
		return
	var row: PanelContainer = _contact_rows[contact_id]
	if is_selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
		style.set_corner_radius_all(6)
		row.add_theme_stylebox_override("panel", style)
	else:
		row.remove_theme_stylebox_override("panel")


func _on_minimize_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
	minimize_requested.emit(self, _title_label.text)
