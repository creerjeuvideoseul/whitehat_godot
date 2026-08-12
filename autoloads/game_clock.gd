extends Node
## Autoload singleton: the in-fiction clock. Runs 10x slower than real time
## (1 in-game second per 10 real seconds) — per the design notes, this is a
## deliberate narrative hint, not a placeholder value to "fix" later.
##
## Only ticks during an active playthrough: main_menu.gd starts/resets it when
## a game begins (new or continued) and options_panel.gd stops it when the
## player leaves back to the main menu. SaveManager reads/writes its value
## at checkpoints — this script has no persistence logic of its own.

signal tick

## Seule la date est figée par la fiction — l'heure de départ vient de
## l'horloge réelle du joueur (voir reset_to_story_start), pas de minuit.
const STORY_START_DATE := {"year": 2030, "month": 2, "day": 2}
const REAL_SECONDS_PER_TICK := 10.0

@onready var _timer: Timer = Timer.new()

var _unix_time: int = 0


func _ready() -> void:
	_timer.wait_time = REAL_SECONDS_PER_TICK
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func get_unix_time() -> int:
	return _unix_time


func set_unix_time(value: int) -> void:
	_unix_time = value


## Call when starting a brand new playthrough — date fixée par la fiction,
## heure alignée sur l'horloge réelle du joueur au moment où il commence.
func reset_to_story_start() -> void:
	var datetime := STORY_START_DATE.duplicate()
	var now := Time.get_time_dict_from_system()
	datetime["hour"] = now["hour"]
	datetime["minute"] = now["minute"]
	datetime["second"] = now["second"]
	_unix_time = int(Time.get_unix_time_from_datetime_dict(datetime))


func start_ticking() -> void:
	_timer.start()


func stop_ticking() -> void:
	_timer.stop()


## "HH:MM" readout for the desktop footer clock.
func get_display_string() -> String:
	var parts := Time.get_datetime_dict_from_unix_time(_unix_time)
	return "%02d:%02d" % [parts.hour, parts.minute]


func _on_tick() -> void:
	_unix_time += 1
	tick.emit()
