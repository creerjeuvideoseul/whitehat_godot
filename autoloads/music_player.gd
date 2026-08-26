extends Node
## Autoload singleton: background music with fade in/out. Being an autoload,
## it survives scene changes, so a fade started right before
## change_scene_to_file() keeps playing out instead of being cut off.
##
## Deux pistes indépendantes, chacune avec son propre fondu :
## - "de fond" (_background_player, play_background()/stop_background()) : la
##   musique d'ambiance d'une scène qui doit pouvoir tourner longtemps sans
##   rapport avec un contenu précis (ex. le bureau après le login OU une
##   reprise de sauvegarde, voir desktop.gd — les deux entrées doivent la
##   relancer, pas seulement la toute première connexion).
## - "au premier plan" (_player, play()/stop() — API historique) : une
##   musique ponctuelle liée à un contenu précis (menu, intro, ou la musique
##   d'un mail crypté, voir mail_section.gd). Toujours prioritaire : play()
##   coupe la musique de fond en cours avant de démarrer la sienne, pour ne
##   jamais les faire jouer en même temps — jamais l'inverse (play_background()
##   ne touche pas à une musique au premier plan déjà en cours).
##
## Loudness itself is not handled here: the player is routed to the "Music"
## audio bus, and the user's volume preference (Settings.music_volume) drives
## that bus directly. This class only ever fades its own volume_db between
## silent and unity (0 dB) so the two concerns don't fight each other.

const MUSIC_BUS := "Music"
const DEFAULT_FADE_SECONDS := 2.0
const SILENT_VOLUME_DB := -40.0

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _background_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _fade_tween: Tween
var _background_fade_tween: Tween


func _ready() -> void:
	_player.bus = MUSIC_BUS
	_background_player.bus = MUSIC_BUS
	add_child(_player)
	add_child(_background_player)


## Fade a track in from silence. Loops by default. Coupe d'abord la musique de
## fond en cours (voir stop_background) : les deux pistes ne jouent jamais en
## même temps, c'est toujours la musique de fond qui laisse la place.
func play(stream: AudioStream, fade_seconds: float = DEFAULT_FADE_SECONDS, loop: bool = true) -> void:
	stop_background(fade_seconds)
	_fade_tween = _play_on(_player, _fade_tween, stream, fade_seconds, loop)


## Fade the current track out to silence, then stop playback.
func stop(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	_fade_tween = _stop_on(_player, _fade_tween, fade_seconds)


## Musique de fond (voir desktop.gd) — même comportement que play() ci-dessus
## mais sur sa propre piste, jamais coupée automatiquement par elle-même :
## seule une musique au premier plan (play()) l'interrompt.
func play_background(stream: AudioStream, fade_seconds: float = DEFAULT_FADE_SECONDS, loop: bool = true) -> void:
	_background_fade_tween = _play_on(_background_player, _background_fade_tween, stream, fade_seconds, loop)


func stop_background(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	_background_fade_tween = _stop_on(_background_player, _background_fade_tween, fade_seconds)


## Fondu d'entrée partagé par play()/play_background() — factorisé puisque les
## deux pistes suivent exactement la même recette, seul le player/tween ciblé
## change.
func _play_on(player: AudioStreamPlayer, fade_tween: Tween, stream: AudioStream, fade_seconds: float, loop: bool) -> Tween:
	# AudioStreamOggVorbis aussi : ce projet mixe .mp3 et .ogg pour la musique
	# (voir desktop.gd::ALIZEE_PHONE_MUSIC), et seul .loop diffère d'un type à
	# l'autre — les deux exposent la même propriété booléenne.
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = loop

	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	player.stream = stream
	player.volume_db = SILENT_VOLUME_DB
	player.play()

	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, fade_seconds)
	return tween


## Fondu de sortie partagé par stop()/stop_background().
func _stop_on(player: AudioStreamPlayer, fade_tween: Tween, fade_seconds: float) -> Tween:
	if not player.playing:
		return fade_tween

	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	tween.tween_callback(player.stop)
	return tween
