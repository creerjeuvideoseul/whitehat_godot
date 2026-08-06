extends Control
class_name UsageGauge
## A 150x10 black-background bar that fills with a 3-stop color gradient
## (white at low load, yellow around the middle, red as it approaches 100%),
## wandering smoothly between `min_percent` and `max_percent` to fake a
## system load reading. Purely decorative — CPU and MEM readouts are the same
## component with different ranges, composed with an external Label in
## desktop_header.tscn (this node doesn't know what it's measuring). Both
## gauges share the same gradient colors on purpose — the color now reflects
## the load itself, not which gauge it is.
##
## Forced spikes/drops (load spikes, 0%) are a later request; keeping the
## wander loop self-contained here means adding that later is a single new
## public method, not a rewrite.

## Couleur à 0% de charge.
@export var low_color: Color = Palette.TEXT_NORMAL
## Couleur au palier intermédiaire (50%) — voir Palette.ALERT_YELLOW.
@export var mid_color: Color = Palette.ALERT_YELLOW
## Couleur à 100% de charge — le rouge "remplissage plein" du projet (voir
## Palette.ALERT_RED_BG), pas Palette.TEXT_DANGER qui est réservé au texte.
@export var high_color: Color = Palette.ALERT_RED_BG

@export var min_percent: float = 40.0
@export var max_percent: float = 60.0

const WANDER_MIN_SECONDS := 1.5
const WANDER_MAX_SECONDS := 3.5

@onready var _fill: ColorRect = %Fill

var _percent: float = 0.0:
	set(value):
		_percent = value
		var ratio := clampf(value / 100.0, 0.0, 1.0)
		_fill.anchor_right = ratio
		_fill.color = _gradient_color(ratio)


## Dégradé en deux segments (blanc→jaune puis jaune→rouge) plutôt qu'un lerp
## à 2 couleurs : un lerp direct blanc→rouge traverserait un rose délavé au
## milieu, pas le jaune vif demandé.
func _gradient_color(ratio: float) -> Color:
	if ratio <= 0.5:
		return low_color.lerp(mid_color, ratio / 0.5)
	return mid_color.lerp(high_color, (ratio - 0.5) / 0.5)


func _ready() -> void:
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
