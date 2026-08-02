extends Node
## Autoload singleton: one-shot sound effects (UI feedback, notifications) —
## as opposed to MusicPlayer's looping/fading background tracks, a distinct
## concern with its own audio bus so it can get independent volume control
## later without touching music.

const SFX_BUS := "SFX"

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	_player.bus = SFX_BUS
	add_child(_player)


func play(stream: AudioStream) -> void:
	_player.stream = stream
	_player.play()
