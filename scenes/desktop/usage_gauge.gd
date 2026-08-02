extends Control
class_name UsageGauge
## A 150x25 black-background bar that fills with `fill_color`, wandering
## smoothly between `min_percent` and `max_percent` to fake a system load
## reading. Purely decorative — CPU and MEM readouts are the same component
## with different color/range, composed with an external Label in
## desktop_header.tscn (this node doesn't know what it's measuring).
##
## Forced spikes/drops (load spikes, 0%) are a later request; keeping the
## wander loop self-contained here means adding that later is a single new
## public method, not a rewrite.

@export var fill_color: Color = Palette.BORDER_ACCENT:
	set(value):
		fill_color = value
		if is_node_ready():
			_fill.color = value

@export var min_percent: float = 40.0
@export var max_percent: float = 60.0

const WANDER_MIN_SECONDS := 1.5
const WANDER_MAX_SECONDS := 3.5

@onready var _fill: ColorRect = %Fill

var _percent: float = 0.0:
	set(value):
		_percent = value
		_fill.anchor_right = clampf(value / 100.0, 0.0, 1.0)


func _ready() -> void:
	_fill.color = fill_color
	_percent = (min_percent + max_percent) / 2.0
	_wander_loop()


func _wander_loop() -> void:
	while true:
		var target := randf_range(min_percent, max_percent)
		var duration := randf_range(WANDER_MIN_SECONDS, WANDER_MAX_SECONDS)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "_percent", target, duration)
		await tween.finished
