extends Node
## Autoload singleton: one-shot sound effects (UI feedback, notifications) —
## as opposed to MusicPlayer's looping/fading background tracks, a distinct
## concern with its own audio bus so it can get independent volume control
## later without touching music.

const SFX_BUS := "SFX"

## Joué à chaque découverte d'indice — un seul point d'écoute sur
## ClueManager.clue_unlocked (qui ne s'émet qu'une fois par indice, jamais en
## rejouant un indice déjà connu) couvre toutes les sources à la fois :
## dialogue, chat en direct, SMS, mail, galerie, OSINT n'ont donc rien de
## spécifique à faire pour ce son, il suffit qu'ils appellent
## ClueManager.unlock() au bon moment (voir IndiceRevealTracker pour les
## écrans scrollables).
const CLUE_REVEAL_SFX := preload("res://assets/audio/sound/tithuh-level-up-02-528919.mp3")
## Laisse un instant au joueur avant de signaler la découverte — un son
## littéralement au pixel près où l'indice devient visible arrivait trop tôt,
## avant même que l'œil n'ait eu le temps de se poser dessus.
const CLUE_REVEAL_DELAY_SECONDS := 1.0

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	_player.bus = SFX_BUS
	add_child(_player)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)


func _on_clue_unlocked(_clue_id: String) -> void:
	await get_tree().create_timer(CLUE_REVEAL_DELAY_SECONDS).timeout
	play(CLUE_REVEAL_SFX)


func play(stream: AudioStream) -> void:
	_player.stream = stream
	_player.play()
