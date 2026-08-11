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

## "Accès interdit" — joué à chaque tentative d'accès à du contenu crypté
## (SMS/mail encore verrouillés) ou à une mauvaise saisie dans le coffre-fort
## du téléphone. Centralisé ici (plutôt qu'un preload dupliqué dans chacun des
## trois appelants) puisque c'est exactement la même faute pour l'utilisateur
## dans les trois cas.
const ACCESS_DENIED_SFX := preload("res://assets/audio/sound/soundreality-ui-no-access-243463.mp3")

## Volume de départ/arrivée d'un fondu d'ambiance (même valeur que
## MusicPlayer.SILENT_VOLUME_DB, dupliquée volontairement pour ne pas coupler
## les deux autoloads pour une seule constante).
const AMBIENT_SILENT_VOLUME_DB := -40.0

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()
## Lecteur dédié aux boucles d'ambiance avec fondu (ex: frappe au clavier
## d'un terminal) — séparé de _player pour qu'un one-shot (découverte
## d'indice) puisse se déclencher sans couper l'ambiance en cours.
@onready var _ambient_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _ambient_fade_tween: Tween


func _ready() -> void:
	_player.bus = SFX_BUS
	_ambient_player.bus = SFX_BUS
	add_child(_player)
	add_child(_ambient_player)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)


func _on_clue_unlocked(_clue_id: String) -> void:
	await get_tree().create_timer(CLUE_REVEAL_DELAY_SECONDS).timeout
	play(CLUE_REVEAL_SFX)


func play(stream: AudioStream) -> void:
	_player.stream = stream
	_player.play()


## Joue `stream` en boucle avec un fondu d'entrée, jusqu'à stop_ambient().
## Utilisé pour un bruitage de fond ponctuel (ex: TerminalConsole.typing_sound)
## plutôt qu'un one-shot instantané.
func play_ambient(stream: AudioStream, fade_in_seconds: float) -> void:
	if stream is AudioStreamMP3:
		stream.loop = true

	if _ambient_fade_tween and _ambient_fade_tween.is_valid():
		_ambient_fade_tween.kill()

	_ambient_player.stream = stream
	_ambient_player.volume_db = AMBIENT_SILENT_VOLUME_DB
	_ambient_player.play()

	_ambient_fade_tween = create_tween()
	_ambient_fade_tween.tween_property(_ambient_player, "volume_db", 0.0, fade_in_seconds)


## Fondu de sortie de l'ambiance en cours, puis arrêt.
func stop_ambient(fade_out_seconds: float) -> void:
	if not _ambient_player.playing:
		return

	if _ambient_fade_tween and _ambient_fade_tween.is_valid():
		_ambient_fade_tween.kill()

	_ambient_fade_tween = create_tween()
	_ambient_fade_tween.tween_property(_ambient_player, "volume_db", AMBIENT_SILENT_VOLUME_DB, fade_out_seconds)
	_ambient_fade_tween.tween_callback(_ambient_player.stop)
