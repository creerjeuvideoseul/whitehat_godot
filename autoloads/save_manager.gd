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
## Instantané séparé du vrai fichier de sauvegarde, pour le bouton DEBUG du
## bureau (voir desktop_footer.gd) — jamais lu/écrit en dehors d'un contexte
## debug (voir capture_debug_checkpoint/load_debug_checkpoint).
const DEBUG_SAVE_PATH := "user://debug_checkpoint.json"

## Emis quand un point de sauvegarde debug vient d'être capturé — pour que
## desktop_footer.gd puisse activer son bouton "y revenir" sans attendre un
## rechargement de scène.
signal debug_checkpoint_captured

var _data: Dictionary = {}
## Un-shot : posé par load_debug_checkpoint(), consommé par desktop.gd à
## l'arrivée sur le bureau pour rejouer directement le terminal de Jean sans
## repasser par tout le fil de discussion (voir consume_debug_replay_jean_terminal).
var _debug_should_replay_jean_terminal: bool = false

## When the current session's unsaved progress started accumulating: either
## the last save_checkpoint() call, or app boot if none happened yet this
## session. Session-local on purpose (Time.get_ticks_msec(), not a persisted
## timestamp) — a fresh app launch has nothing unsaved yet, regardless of
## how long ago the save file itself was last written.
var _last_checkpoint_ticks_msec: int = 0


func _ready() -> void:
	_last_checkpoint_ticks_msec = Time.get_ticks_msec()
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
## action. Updates fields in place rather than replacing `_data` outright,
## so anything staged via record_conversation() beforehand isn't lost.
func save_checkpoint(checkpoint_scene: String) -> void:
	_data["version"] = SAVE_VERSION
	_data["checkpoint_scene"] = checkpoint_scene
	_data["pseudo"] = PlayerSession.pseudo
	_data["game_unix_time"] = GameClock.get_unix_time()
	_data["story_vars"] = StoryVars.get_all()
	_data["unlocked_indices"] = ClueManager.get_unlocked_ids()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data))
	_last_checkpoint_ticks_msec = Time.get_ticks_msec()


## Push the saved pseudo back into PlayerSession before resuming a scene
## that reads it (e.g. the desktop).
func restore_player_session() -> void:
	PlayerSession.pseudo = _data.get("pseudo", "")


## Push the saved in-fiction time back into GameClock. Caller still needs to
## call GameClock.start_ticking() afterwards — restoring a value and
## resuming its countdown are separate decisions.
func restore_game_clock() -> void:
	GameClock.set_unix_time(_data.get("game_unix_time", 0))


## Push saved narrative variables (player_emotion, etc.) back into StoryVars.
func restore_story_vars() -> void:
	StoryVars.load_all(_data.get("story_vars", {}))


## Push the saved set of unlocked clue ids back into ClueManager.
func restore_unlocked_indices() -> void:
	ClueManager.load_unlocked_ids(_data.get("unlocked_indices", []))


## Stage a finished conversation's rendered message log in memory, keyed by
## contact id (e.g. "relayghost"). Not written to disk until the next
## save_checkpoint() call — a conversation only "counts" once the checkpoint
## after it actually happens, same as everything else this session.
func record_conversation(contact_id: String, messages: Array) -> void:
	var conversations: Dictionary = _data.get("conversations", {})
	conversations[contact_id] = { "log": messages, "complete": true }
	_data["conversations"] = conversations


## The rendered message log for a contact, as it was last shown — empty if
## that conversation hasn't been recorded yet.
func get_conversation_log(contact_id: String) -> Array:
	var conversations: Dictionary = _data.get("conversations", {})
	return conversations.get(contact_id, {}).get("log", [])


func is_conversation_complete(contact_id: String) -> bool:
	var conversations: Dictionary = _data.get("conversations", {})
	return conversations.get(contact_id, {}).get("complete", false)


## Ajoute une pensée à l'historique consultable (voir ThoughtLogWindow) — pas
## de dédoublonnage voulu, la même pensée peut légitimement revenir plusieurs
## fois (ex. indices du coffre-fort). `translation_key` vide si le texte n'a
## pas de clé ui.csv (ex. pensées déclenchées depuis le mail, déjà résolues
## par langue dans le JSON de données — voir mail_section.gd) : get_thought_log()
## retombe alors sur `text` tel quel plutôt que sur une clé de traduction.
func record_thought(text: String, translation_key: String = "") -> void:
	var thought_log: Array = _data.get("thought_log", [])
	thought_log.append({
		"text": text,
		"key": translation_key,
		"game_unix_time": GameClock.get_unix_time(),
	})
	_data["thought_log"] = thought_log


## Historique complet, du plus ancien au plus récent (voir record_thought) —
## chaque entrée est {"text": String, "key": String, "game_unix_time": int}.
func get_thought_log() -> Array:
	return _data.get("thought_log", [])


## How long the player has been playing since their progress was last
## checkpointed — i.e. how much would be lost by quitting right now.
func get_minutes_since_checkpoint() -> int:
	var elapsed_msec := Time.get_ticks_msec() - _last_checkpoint_ticks_msec
	return int(elapsed_msec / 60000.0)


## A appeler sur chaque ligne de dialogue affichée (même usage que
## ClueManager.unlock_from_tags) : capture un point de sauvegarde debug si la
## ligne porte le tag [#debug_checkpoint], ne fait rien sinon. Sûr d'appeler
## systématiquement, la plupart des lignes n'ont pas ce tag.
func maybe_capture_debug_checkpoint(line: DialogueLine) -> void:
	if line.has_tag("debug_checkpoint"):
		capture_debug_checkpoint()


## Debug only (voir Settings.IS_PRODUCTION, qui garde le bouton s'en servant —
## voir desktop_footer.gd) : capture un instantané séparé du vrai fichier de
## sauvegarde, à un point choisi dans un fichier .dialogue via le tag
## [#debug_checkpoint]. Ne touche jamais SAVE_PATH — la vraie progression du
## joueur n'est pas affectée par cette capture.
func capture_debug_checkpoint() -> void:
	var snapshot := {
		"version": SAVE_VERSION,
		"checkpoint_scene": get_checkpoint_scene(),
		"pseudo": PlayerSession.pseudo,
		"game_unix_time": GameClock.get_unix_time(),
		"story_vars": StoryVars.get_all(),
		"unlocked_indices": ClueManager.get_unlocked_ids(),
		"conversations": _data.get("conversations", {}).duplicate(true),
		"thought_log": _data.get("thought_log", []).duplicate(true),
	}
	var file := FileAccess.open(DEBUG_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(snapshot))
	debug_checkpoint_captured.emit()


func has_debug_checkpoint() -> bool:
	return FileAccess.file_exists(DEBUG_SAVE_PATH)


## Recharge l'instantané debug par-dessus l'état courant en mémoire (comme
## _load() au démarrage) — n'écrit rien sur le vrai fichier de sauvegarde à
## ce stade. Pose _debug_should_replay_jean_terminal : la conversation avec
## Jean n'est volontairement pas marquée complète dans l'instantané (voir
## capture_debug_checkpoint, pris avant la fin réelle), donc desktop.gd doit
## rejouer le terminal directement plutôt que de suivre son chemin normal.
func load_debug_checkpoint() -> void:
	if not FileAccess.file_exists(DEBUG_SAVE_PATH):
		return
	var file := FileAccess.open(DEBUG_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data = parsed
		_debug_should_replay_jean_terminal = true


## Un-shot : vrai une seule fois après un load_debug_checkpoint(), puis se
## remet à faux — pour qu'un "Continuer" normal, plus tard dans la session,
## ne redéclenche pas le terminal de Jean par erreur.
func consume_debug_replay_jean_terminal() -> bool:
	var value := _debug_should_replay_jean_terminal
	_debug_should_replay_jean_terminal = false
	return value


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
