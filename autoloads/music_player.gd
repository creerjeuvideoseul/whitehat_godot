extends Node
## Autoload singleton: background music with fade in/out. Being an autoload,
## it survives scene changes, so a fade started right before
## change_scene_to_file() keeps playing out instead of being cut off.
##
## Loudness itself is not handled here: the player is routed to the "Music"
## audio bus, and the user's volume preference (Settings.music_volume) drives
## that bus directly. This class only ever fades its own volume_db between
## silent and unity (0 dB) so the two concerns don't fight each other.

const MUSIC_BUS := "Music"
const DEFAULT_FADE_SECONDS := 2.0
const SILENT_VOLUME_DB := -40.0

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()

var _fade_tween: Tween


func _ready() -> void:
	_player.bus = MUSIC_BUS
	add_child(_player)


## Fade a track in from silence. Loops by default.
func play(stream: AudioStream, fade_seconds: float = DEFAULT_FADE_SECONDS, loop: bool = true) -> void:
	if stream is AudioStreamMP3:
		stream.loop = loop

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_player.stream = stream
	_player.volume_db = SILENT_VOLUME_DB
	_player.play()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", 0.0, fade_seconds)


## Fade the current track out to silence, then stop playback.
func stop(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	if not _player.playing:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	_fade_tween.tween_callback(_player.stop)
