extends Control
## The desktop's bottom bar. Left side is a taskbar for minimized windows
## (chat/phone/mail/file explorer, ...) — see add_minimized_window(). Right
## side is connection/session status: VPN, TOR relay count, a decorative
## signal readout, and the in-fiction clock (GameClock).

@onready var _clock_label: Label = %ClockLabel
@onready var _minimized_windows_bar: HBoxContainer = %MinimizedWindowsBar
@onready var _debug_clue_button: Button = %DebugClueButton

## Toggle state for the debug button — it doesn't ask ClueManager "is
## everything unlocked", it just remembers which action it last took.
var _debug_indices_unlocked: bool = false


func _ready() -> void:
	_update_clock_label()
	GameClock.tick.connect(_update_clock_label)

	if Settings.IS_PRODUCTION:
		_debug_clue_button.queue_free()
	else:
		_debug_clue_button.pressed.connect(_on_debug_clue_button_pressed)


func _update_clock_label() -> void:
	_clock_label.text = GameClock.get_display_string()


## Add a taskbar icon for a minimized window. Clicking it calls on_restore
## and removes the icon — the footer doesn't know or care what kind of
## window it is, just its title and how to bring it back.
func add_minimized_window(window_title: String, on_restore: Callable) -> void:
	var button := Button.new()
	button.text = window_title
	button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(func() -> void:
		on_restore.call()
		button.queue_free()
	)
	_minimized_windows_bar.add_child(button)


## For a window reopened some other way than clicking its own taskbar icon
## (e.g. its header shortcut) — drops the now-stale icon so it doesn't sit
## there claiming to "restore" a window that's already showing.
func remove_minimized_window(window_title: String) -> void:
	for child in _minimized_windows_bar.get_children():
		if child is Button and child.text == window_title:
			child.queue_free()


## Debug only (see Settings.IS_PRODUCTION) : bascule tous les indices de
## toutes les missions entre débloqué et verrouillé. Casse volontairement la
## cohérence de la sauvegarde — c'est un outil de test.
func _on_debug_clue_button_pressed() -> void:
	_debug_indices_unlocked = not _debug_indices_unlocked
	if _debug_indices_unlocked:
		ClueManager.unlock_all()
	else:
		ClueManager.lock_all()
