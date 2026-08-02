extends Control
## The desktop's bottom bar. Left side is a taskbar for minimized windows
## (chat/phone/mail/file explorer, ...) — see add_minimized_window(). Right
## side is connection/session status: VPN, TOR relay count, a decorative
## signal readout, and the in-fiction clock (GameClock).

@onready var _clock_label: Label = %ClockLabel
@onready var _minimized_windows_bar: HBoxContainer = %MinimizedWindowsBar


func _ready() -> void:
	_update_clock_label()
	GameClock.tick.connect(_update_clock_label)


func _update_clock_label() -> void:
	_clock_label.text = GameClock.get_display_string()


## Add a taskbar icon for a minimized window. Clicking it calls on_restore
## and removes the icon — the footer doesn't know or care what kind of
## window it is, just its title and how to bring it back.
func add_minimized_window(window_title: String, on_restore: Callable) -> void:
	var button := Button.new()
	button.text = window_title
	button.pressed.connect(func() -> void:
		on_restore.call()
		button.queue_free()
	)
	_minimized_windows_bar.add_child(button)
