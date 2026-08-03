extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). Owns spawning windows into WindowLayer, the area reserved between
## the header and footer, and wires each window's minimize button to the
## footer's taskbar. The header/footer otherwise manage themselves
## (desktop_header.gd, desktop_footer.gd).

const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const CLUE_BOARD_WINDOW := preload("res://scenes/desktop/windows/clue_board_window.tscn")
## The mission the "Indice" button currently opens. No mission-selection UI
## exists yet, so this is hardcoded for now — same simplification the chat
## contacts already make (see JEAN_REVEAL_DELAY_SECONDS below).
const CURRENT_MISSION_ID := 1
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
@onready var _header: DesktopHeader = %DesktopHeader

## Kept so pressing "Indice" a second time re-shows the same window (and its
## already-unlocked state) instead of stacking duplicates — it can't be
## closed, only minimized, so a second instance would linger forever.
var _clue_board_window: ClueBoardWindow = null
## Last title it minimized under, so re-showing it via the header button (as
## opposed to its own taskbar icon) can clear that now-stale icon.
var _clue_board_window_title: String = ""


func _ready() -> void:
	_header.clue_button_pressed.connect(_on_clue_button_pressed)
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


## Untyped on purpose: ChatWindow and ClueBoardWindow both expose the same
## minimize_requested(window, window_title) signal by convention, but don't
## share a base class — a Control-typed parameter would make the static
## checker reject a signal it can't see on Control itself.
func _open_window(window) -> void:
	window.minimize_requested.connect(_on_window_minimize_requested)
	_window_layer.add_child(window)


func _on_window_minimize_requested(window: Control, window_title: String) -> void:
	if window == _clue_board_window:
		_clue_board_window_title = window_title
	_footer.add_minimized_window(window_title, func() -> void: window.show())


## "Indice" always reopens the same board so its layout/unlocked state isn't
## rebuilt from scratch every click — only the first press instantiates it.
## It has no close button (only minimize), so a second instance would linger
## on screen forever if we let one get created.
func _on_clue_button_pressed() -> void:
	if is_instance_valid(_clue_board_window):
		_footer.remove_minimized_window(_clue_board_window_title)
		_clue_board_window.show()
		return

	_clue_board_window = CLUE_BOARD_WINDOW.instantiate()
	_clue_board_window.mission_id = CURRENT_MISSION_ID
	_open_window(_clue_board_window)
