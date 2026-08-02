extends Control
## The desktop's top bar: OSINT search entry point (left) and system status
## readouts (right) — TOR indicator, CPU/MEM gauges, current pseudo. Always
## on screen in desktop.tscn; future windows (chat/phone/mail/...) render
## below it, never over it.

const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4

@onready var _tor_icon: TextureRect = %TorIcon
@onready var _pseudo_label: Label = %PseudoLabel


func _ready() -> void:
	_pseudo_label.text = "%s@whos:~" % PlayerSession.pseudo
	_start_tor_blink()


func _start_tor_blink() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_tor_icon, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	tween.tween_property(_tor_icon, "modulate:a", 1.0, BLINK_SECONDS)
