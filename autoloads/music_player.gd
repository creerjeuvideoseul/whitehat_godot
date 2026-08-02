extends Node
## Autoload singleton: background music with fade in/out. Being an autoload,
## it survives scene changes, so a fade started right before
## change_scene_to_file() keeps playing out instead of being cut off.

const DEFAULT_FADE_SECONDS := 2.0
const DEFAULT_VOLUME_DB := -6.0
const SILENT_VOLUME_DB := -40.0

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()

var _fade_tween: Tween


func _ready() -> void:
	add_child(_player)


## Fade a track in from silence. Loops by default.
func play(stream: AudioStream, fade_seconds: float = DEFAULT_FADE_SECONDS, target_volume_db: float = DEFAULT_VOLUME_DB, loop: bool = true) -> void:
	if stream is AudioStreamMP3:
		stream.loop = loop

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_player.stream = stream
	_player.volume_db = SILENT_VOLUME_DB
	_player.play()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target_volume_db, fade_seconds)


## Fade the current track out to silence, then stop playback.
func stop(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	if not _player.playing:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	_fade_tween.tween_callback(_player.stop)
