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
## spécifique à faire pour ce son — il se déclenche tout seul dès que le
## joueur clique le passage color=indice correspondant (voir
## ClueManager.mark_clicked()).
const CLUE_REVEAL_SFX := preload("res://assets/audio/sound/tithuh-level-up-02-528919.mp3")
## Laisse un instant au joueur avant de signaler la découverte — un son
## littéralement au pixel près où l'indice devient visible arrivait trop tôt,
## avant même que l'œil n'ait eu le temps de se poser dessus.
const CLUE_REVEAL_DELAY_SECONDS := 3.0

## "Accès interdit" — joué à chaque tentative d'accès à du contenu crypté
## (SMS/mail encore verrouillés) ou à une mauvaise saisie dans le coffre-fort
## du téléphone. Centralisé ici (plutôt qu'un preload dupliqué dans chacun des
## trois appelants) puisque c'est exactement la même faute pour l'utilisateur
## dans les trois cas.
const ACCESS_DENIED_SFX := preload("res://assets/audio/sound/soundreality-ui-no-access-243463.mp3")

## "Grande révélation" — joué à chaque jalon narratif majeur : l'apparition
## de la fenêtre "Piratage — PC de la mère" et le déverrouillage réussi du
## coffre-fort (vault_section.gd). Centralisé ici plutôt que dupliqué en
## preload dans chacun des deux, même raison qu'ACCESS_DENIED_SFX ci-dessus.
const MAJOR_REVEAL_SFX := preload("res://assets/audio/sound/soundreality-notification-center-443093.mp3")

## Apparition du téléphone d'Alizée sur le bureau (desktop.gd) — distinct de
## MAJOR_REVEAL_SFX ci-dessus : un son de notification plutôt qu'une
## "révélation", propre à ce moment précis.
const ALIZEE_PHONE_REVEAL_SFX := preload("res://assets/audio/sound/soundreality-notification-center-443093.mp3")

## Petit "clic" très court pour meubler le faux OS — sélectionner une
## conversation SMS, ouvrir un mail, ouvrir une photo de la galerie. Pas un
## indice narratif comme les sons ci-dessus, juste du feedback UI ; centralisé
## quand même pour la même raison qu'ACCESS_DENIED_SFX (un seul preload, trois
## appelants sans lien entre eux).
const UI_CLICK_SFX := preload("res://assets/audio/sound/u_o8xh7gwsrj-bubble_pop_1-476367-2.mp3")

## Glissement du panneau latéral Collecte d'indices (DesktopCluePanel) entre
## ses 3 niveaux — distinct d'UI_CLICK_SFX ci-dessus (déjà joué au clic sur le
## bouton qui déclenche ce glissement) : ce second son accompagne le
## mouvement du cadre lui-même, pas le clic qui le lance.
const UI_SLIDE_SFX := preload("res://assets/audio/sound/ui_slide.ogg")

## Joué à chaque clic sur un passage color=indice (voir
## RichTextMarkup.wire_indice_interactions), qu'il débloque ou non un nouvel
## indice — contrairement à CLUE_REVEAL_SFX ci-dessus (un seul point d'écoute
## sur ClueManager.clue_unlocked, jamais rejoué), celui-ci écoute
## ClueManager.clue_clicked, qui se déclenche à chaque clic y compris sur un
## indice déjà connu (voir clue_manager.gd).
const CLUE_CLICK_SFX := preload("res://assets/audio/sound/soundshelfstudio-deep-ui-chime-585839.mp3")

## Frappe au clavier pendant les lignes "tapées par le joueur" d'un
## TerminalConsole (voir TerminalConsole.typing_sound / TerminalLine.plays_typing_sound)
## — dump du téléphone d'Alizée, connexion RDP du PC de la mère (desktop.gd),
## envoi du rapport final (report_generation_screen.gd) — et du monologue de
## rédemption de l'intro (introduction.gd, MonologueScreen.typing_sound), même
## logique ("le joueur tape/écrit"). Centralisé ici (plutôt qu'un preload
## dupliqué dans chaque script) une fois qu'un second script en a eu besoin,
## même raison qu'ACCESS_DENIED_SFX.
const TERMINAL_TYPING_SFX := preload("res://assets/audio/sound/virtual_vibes-fast-keyboard-typing-423436.mp3")

## Joué à la fin de l'animation de fusion de deux indices liés (voir
## ClueFusion, desktop.gd) — juste avant que l'ensemble ne glisse vers le
## panneau Collecte d'indices, pour marquer que le joueur vient de résoudre
## une question grâce à une réponse trouvée ailleurs (voir clues_link.txt).
const CLUE_FUSION_SFX := preload("res://assets/audio/sound/aviana_phoenix-soft-transition-338894.mp3")

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
	ClueManager.clue_clicked.connect(_on_clue_clicked)


func _on_clue_unlocked(_clue_id: String) -> void:
	await get_tree().create_timer(CLUE_REVEAL_DELAY_SECONDS).timeout
	play(CLUE_REVEAL_SFX)


func _on_clue_clicked(_clue_id: String) -> void:
	play(CLUE_CLICK_SFX)


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
