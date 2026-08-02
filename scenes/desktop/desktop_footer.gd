extends Control
## The desktop's bottom bar. Left side is reserved and empty for now — future
## minimized windows (chat/phone/mail/file explorer, once they exist) will
## dock icons into MinimizedWindowsBar as a taskbar. Right side is
## connection/session status: VPN, TOR relay count, a decorative signal
## readout, and the in-fiction clock (GameClock).

@onready var _clock_label: Label = %ClockLabel


func _ready() -> void:
	_update_clock_label()
	GameClock.tick.connect(_update_clock_label)


func _update_clock_label() -> void:
	_clock_label.text = GameClock.get_display_string()
