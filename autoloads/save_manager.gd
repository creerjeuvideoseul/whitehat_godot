extends Node
## Autoload singleton: the player's single ongoing playthrough checkpoint.
## Stored as JSON rather than a serialized Resource, so the save file's
## shape stays stable across script/class refactors instead of being tied
## to a specific Resource script path (a common trap when Godot save games
## are written via ResourceSaver directly).
##
## Distinct from PlayerSession (in-memory only, current run) and Settings
## (user preferences): this is persisted *narrative* progress.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

var _data: Dictionary = {}


func _ready() -> void:
	_load()


## True once at least one checkpoint has been written.
func has_save() -> bool:
	return not _data.is_empty()


## Scene to resume at when the player picks "Continuer".
func get_checkpoint_scene() -> String:
	return _data.get("checkpoint_scene", "")


## Write a checkpoint: which scene to resume at, plus a snapshot of the
## player state that needs to survive a restart. Call this at narrative
## checkpoints (mission boundaries, key story beats) rather than on every
## action.
func save_checkpoint(checkpoint_scene: String) -> void:
	_data = {
		"version": SAVE_VERSION,
		"checkpoint_scene": checkpoint_scene,
		"pseudo": PlayerSession.pseudo,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data))


## Push the saved pseudo back into PlayerSession before resuming a scene
## that reads it (e.g. the welcome screen).
func restore_player_session() -> void:
	PlayerSession.pseudo = _data.get("pseudo", "")


func delete_save() -> void:
	_data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data = parsed
