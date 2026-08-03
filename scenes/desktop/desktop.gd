extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). Owns spawning windows into WindowLayer, the area reserved between
## the header and footer, and wires each window's minimize button to the
## footer's taskbar. The header/footer otherwise manage themselves
## (desktop_header.gd, desktop_footer.gd).

const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const ANONGHOST_AVATAR := preload("res://assets/avatar/anonghost_avatar.png")
const ANONGHOST_DIALOGUE: DialogueResource = preload("res://dialogue/anonghost_intro.dialogue")
const JEAN_AVATAR := preload("res://assets/avatar/portrait_jean.webp")
const JEAN_DIALOGUE: DialogueResource = preload("res://dialogue/jean_intro.dialogue")

## The chat window auto-opens on desktop load for now — there's no "how do
## you open a window" system yet (icons, notifications, ...), so this is
## provisional wiring to keep everything testable end to end.

## Jean only shows up in the sidebar once AnonGhost's briefing is over, with
## a short pause first so the two don't blur together.
const JEAN_REVEAL_DELAY_SECONDS := 1.0

@onready var _window_layer: Control = %WindowLayer
@onready var _footer: Control = %DesktopFooter


func _ready() -> void:
	_open_window(_build_chat_window())


func _build_chat_window() -> ChatWindow:
	var window: ChatWindow = CHAT_WINDOW.instantiate()
	window.contacts = [_build_anonghost_contact()]
	window.contact_conversation_finished.connect(func(contact_id: String) -> void:
		if contact_id == "anonghost":
			await get_tree().create_timer(JEAN_REVEAL_DELAY_SECONDS).timeout
			window.add_contact(_build_jean_contact())
	)
	return window


func _build_anonghost_contact() -> ChatContact:
	var contact := ChatContact.new()
	contact.contact_id = "anonghost"
	contact.contact_name = "AnonGhost"
	contact.avatar = ANONGHOST_AVATAR
	contact.dialogue_resource = ANONGHOST_DIALOGUE
	return contact


## Jean's messages use a distinct blue tint (ChatContact.bubble_color) so
## the two contacts stay visually distinguishable inside the same window —
## the window itself keeps the default green chrome shared by all contacts.
func _build_jean_contact() -> ChatContact:
	var contact := ChatContact.new()
	contact.contact_id = "jean_ranoud"
	contact.contact_name = "Jean Ranoud"
	contact.avatar = JEAN_AVATAR
	contact.dialogue_resource = JEAN_DIALOGUE
	contact.bubble_color = Palette.BUBBLE_BLUE
	return contact


func _open_window(window: ChatWindow) -> void:
	window.minimize_requested.connect(_on_window_minimize_requested)
	_window_layer.add_child(window)


func _on_window_minimize_requested(window: Control, window_title: String) -> void:
	_footer.add_minimized_window(window_title, func() -> void: window.show())
