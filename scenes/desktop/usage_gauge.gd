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
## Forced spikes (set_spike_range/restore_normal_range, see desktop_header.gd's
## CPU gauge during a system window) reuse the same self-contained wander
## chain rather than a separate code path.

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
## Durée du saut quand set_spike_range()/restore_normal_range() force une
## nouvelle fourchette — plus court qu'un palier de wander normal pour que le
## changement se voie tout de suite plutôt que de se fondre dans le bruit.
const SPIKE_JUMP_SECONDS := 0.4

@onready var _fill: ColorRect = %Fill

var _percent: float = 0.0:
	set(value):
		_percent = value
		var ratio := clampf(value / 100.0, 0.0, 1.0)
		_fill.anchor_right = ratio
		_fill.color = _gradient_color(ratio)

## Fourchette d'origine (celle configurée sur l'instance dans la scène) —
## capturée à _ready() pour que restore_normal_range() puisse y revenir sans
## que l'appelant ait besoin de la reconnaître lui-même.
var _normal_min_percent: float
var _normal_max_percent: float
var _wander_tween: Tween


## Dégradé en deux segments (blanc→jaune puis jaune→rouge) plutôt qu'un lerp
## à 2 couleurs : un lerp direct blanc→rouge traverserait un rose délavé au
## milieu, pas le jaune vif demandé.
func _gradient_color(ratio: float) -> Color:
	if ratio <= 0.5:
		return low_color.lerp(mid_color, ratio / 0.5)
	return mid_color.lerp(high_color, (ratio - 0.5) / 0.5)


func _ready() -> void:
	_normal_min_percent = min_percent
	_normal_max_percent = max_percent
	_percent = (min_percent + max_percent) / 2.0
	_wander_step()


## Une étape du "wander" qui s'enchaîne elle-même (plutôt qu'une boucle
## while) : un forçage externe (set_spike_range/restore_normal_range) peut
## ainsi tuer le palier en cours et relancer proprement la chaîne dessus,
## sans laisser deux boucles concurrentes tourner en même temps.
func _wander_step() -> void:
	var target := randf_range(min_percent, max_percent)
	var duration := randf_range(WANDER_MIN_SECONDS, WANDER_MAX_SECONDS)
	_wander_tween = create_tween()
	_wander_tween.set_trans(Tween.TRANS_SINE)
	_wander_tween.tween_property(self, "_percent", target, duration)
	await _wander_tween.finished
	_wander_step()


## Force un saut immédiat vers une fourchette donnée (ex: pic de charge
## pendant qu'une fenêtre système tourne, voir desktop_header.gd) — remplace
## min_percent/max_percent tant que restore_normal_range() n'est pas appelé.
func set_spike_range(spike_min: float, spike_max: float) -> void:
	min_percent = spike_min
	max_percent = spike_max
	_jump_and_resume_wander()


## Revient à la fourchette d'origine (celle configurée sur l'instance dans la
## scène) après un set_spike_range().
func restore_normal_range() -> void:
	min_percent = _normal_min_percent
	max_percent = _normal_max_percent
	_jump_and_resume_wander()


func _jump_and_resume_wander() -> void:
	if _wander_tween and _wander_tween.is_valid():
		_wander_tween.kill()
	var target := randf_range(min_percent, max_percent)
	_wander_tween = create_tween()
	_wander_tween.set_trans(Tween.TRANS_SINE)
	_wander_tween.tween_property(self, "_percent", target, SPIKE_JUMP_SECONDS)
	await _wander_tween.finished
	_wander_step()
