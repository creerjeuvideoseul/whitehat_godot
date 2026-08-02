extends Control
class_name ChatWindow
## A reusable "encrypted chat" window: a contacts sidebar + scrolling message
## thread, driven by a dialogue_manager DialogueResource. Built for AnonGhost
## first, meant to be reused as-is for Jean Ranoud and later contacts —
## only the @export fields change per instance, not this script.
##
## No close button by design: minimizing is the only way to dismiss it (see
## minimize_requested), matching "on ne peut pas fermer la fenêtre, juste la
## réduire."

signal minimize_requested(window: Control, window_title: String)

const CHAT_BUBBLE := preload("res://scenes/desktop/windows/chat_bubble.tscn")
const CHOICE_SOUND := preload("res://assets/audio/sound/mixkit-correct-answer-notification-947.mp3")
const PLAYER_CHARACTER := "Player"
const TYPING_INDICATOR_SECONDS := 0.9

@export var contact_id: String = ""
@export var contact_name: String = ""
@export var contact_avatar: Texture2D
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title: String = "start"

@onready var _title_bar: Control = %TitleBar
@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _contacts_list: VBoxContainer = %ContactsList
@onready var _messages_list: VBoxContainer = %MessagesList
@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var _response_template: Button = %ResponseTemplate

var _log: Array = []
var _current_label: DialogueLabel = null
var _dragging: bool = false
var _connecting_line: Label = null


func _ready() -> void:
	_add_contact_entry(contact_name, contact_avatar)

	_responses_menu.response_template = _response_template
	_responses_menu.response_selected.connect(_on_response_selected)
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	gui_input.connect(_on_gui_input)

	if SaveManager.is_conversation_complete(contact_id):
		_replay_saved_log()
	else:
		_show_connecting_line()
		_advance(dialogue_start_title)


## Anywhere in the window: a click completes the line currently typing out,
## instead of waiting for it. Buttons (responses, minimize) consume their
## own clicks first, so this only fires on empty space / bubble clicks.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(_current_label) and _current_label.is_typing:
			_current_label.skip_typing()


## Drag by the title bar only (like a real OS window), clamped so the
## window can't be dragged past the desktop's edges. MinimizeButton still
## gets its own clicks first — Buttons consume input before it reaches here.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var max_position: Vector2 = get_parent_area_size() - size
		position = (position + event.relative).clamp(Vector2.ZERO, max_position)


## A plain command-line style status line (no bubble), shown only while
## waiting for the very first live message — never on a replayed/completed
## conversation, since there's nothing to "wait" for there.
func _show_connecting_line() -> void:
	_connecting_line = Label.new()
	_connecting_line.text = "CHAT_CONNECTING_LINE"
	_connecting_line.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	_connecting_line.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	_messages_list.add_child(_connecting_line)
	_messages_list.move_child(_connecting_line, _responses_menu.get_index())
	_scroll_to_bottom()


func _clear_connecting_line() -> void:
	if is_instance_valid(_connecting_line):
		_connecting_line.queue_free()
		_connecting_line = null


func _replay_saved_log() -> void:
	for entry in SaveManager.get_conversation_log(contact_id):
		var line := DialogueLine.new()
		line.character = entry.character
		line.text = entry.text
		_add_bubble(line, entry.character == PLAYER_CHARACTER)
	_scroll_to_bottom()


func _advance(next_id: String) -> void:
	var line: DialogueLine = await dialogue_resource.get_next_dialogue_line(next_id, [self])
	if line == null:
		_on_conversation_finished()
		return
	await _display_line(line)


func _display_line(line: DialogueLine) -> void:
	_clear_connecting_line()

	var is_player: bool = line.character == PLAYER_CHARACTER

	if not is_player:
		await _show_typing_indicator()

	var label := _add_bubble(line, is_player)
	_current_label = label
	label.type_out()
	await label.finished_typing
	_current_label = null

	_log.append({ "character": line.character, "text": line.text })

	if line.responses.size() > 0:
		_responses_menu.responses = line.responses
		_messages_list.move_child(_responses_menu, _messages_list.get_child_count() - 1)
		_responses_menu.show()
		SfxPlayer.play(CHOICE_SOUND)
		_scroll_to_bottom()
	else:
		await _advance(line.next_id)


func _on_response_selected(response: DialogueResponse) -> void:
	_responses_menu.hide()
	await _advance(response.next_id)


func _on_conversation_finished() -> void:
	SaveManager.record_conversation(contact_id, _log)
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())


func _show_typing_indicator() -> void:
	var placeholder := DialogueLine.new()
	placeholder.text = "..."

	var bubble: ChatBubble = CHAT_BUBBLE.instantiate()
	_messages_list.add_child(bubble)
	_messages_list.move_child(bubble, _responses_menu.get_index())
	bubble.configure(placeholder, false)
	_scroll_to_bottom()

	await get_tree().create_timer(TYPING_INDICATOR_SECONDS).timeout
	bubble.queue_free()


func _add_bubble(line: DialogueLine, is_player: bool) -> DialogueLabel:
	var bubble: ChatBubble = CHAT_BUBBLE.instantiate()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN

	_messages_list.add_child(bubble)
	_messages_list.move_child(bubble, _responses_menu.get_index())

	var label := bubble.configure(line, is_player)
	_scroll_to_bottom()
	return label


func _add_contact_entry(display_name: String, avatar: Texture2D) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var avatar_frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_width_left = 3
	frame_style.border_width_top = 3
	frame_style.border_width_right = 3
	frame_style.border_width_bottom = 3
	frame_style.border_color = Palette.BORDER_ACCENT
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
	row.add_child(avatar_frame)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	name_label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	row.add_child(name_label)

	_contacts_list.add_child(row)


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


func _on_minimize_pressed() -> void:
	hide()
	minimize_requested.emit(self, _title_label.text)
