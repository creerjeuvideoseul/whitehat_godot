extends Control
## Placeholder post-login screen: greets the player by their chosen pseudo.

@onready var _message_label: Label = %MessageLabel
@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer

var _start_ticks_msec: int = 0

func _ready() -> void:
	_start_ticks_msec = Time.get_ticks_msec()
	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()
	_message_label.text = "Bonjour %s. Merci." % PlayerSession.pseudo

func _update_uptime_label() -> void:
	var elapsed_sec: int = int((Time.get_ticks_msec() - _start_ticks_msec) / 1000.0)
	var days: int = elapsed_sec / 86400
	var hours: int = (elapsed_sec % 86400) / 3600
	var minutes: int = (elapsed_sec % 3600) / 60
	_uptime_label.text = "Up %dd %02d:%02d" % [days, hours, minutes]
