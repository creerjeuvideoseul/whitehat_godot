extends Control
class_name MonologueScreen
## Écran noir avec un texte qui s'écrit lettre par lettre (même mécanique de
## frappe que le reste du jeu, voir DialogueLabel), dans un cadre invisible
## centré à l'écran, texte aligné à gauche. Générique et réutilisable comme
## TerminalConsole (voir scenes/ui/terminal_console.gd) : rien n'est en dur
## ici, `text`/`music`/`typing_sound` viennent de l'appelant — voir introduction.gd pour
## l'usage actuel (monologue de rédemption juste après le JT).
##
## Ajoutée directement en enfant de la scène appelante (pas de CanvasLayer
## dédié) : c'est une étape de narration ponctuelle propre à l'appelant,
## comme TerminalConsole.

signal closed

## Texte affiché (BBCode autorisé, ex. [b][color=...]...[/color][/b] pour un
## mot mis en valeur) — à définir avant add_child(), comme TerminalConsole.lines.
var text: String = ""
## Musique de fond, avec fondu d'entrée/sortie (voir music_fade_seconds) —
## laissée à null : pas de musique. À définir avant add_child(), comme `text`.
var music: AudioStream = null
var music_fade_seconds: float = 1.0
## Bruitage de frappe au clavier pendant que le texte s'écrit (même mécanique
## que TerminalConsole.typing_sound) — laissé à null : pas de bruitage. À
## définir avant add_child(), comme `text`.
var typing_sound: AudioStream = null

## Plus lent que le défaut de DialogueLabel (0.02s/caractère) : rythme plus
## solennel, adapté à un monologue plutôt qu'à un dialogue qui s'enchaîne vite.
const SECONDS_PER_STEP := 0.035
## Même durée de fondu que TerminalConsole.TYPING_SOUND_FADE_SECONDS, pour le
## même bruitage de frappe.
const TYPING_SOUND_FADE_SECONDS := 0.1
## Pause après la fin de la frappe avant que l'indicateur "cliquez pour
## continuer" apparaisse — laisse un instant de silence avant de rendre la
## main au joueur, plutôt que de l'afficher instantanément sur le dernier mot.
const CONTINUE_HINT_DELAY_SECONDS := 0.6

@onready var _label: DialogueLabel = %Label
@onready var _continue_hint: Label = %ContinueHint

var _can_continue: bool = false


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if music != null:
		MusicPlayer.play(music, music_fade_seconds)
	_play()


func _play() -> void:
	var dialogue_line := DialogueLine.new()
	dialogue_line.text = text
	_label.dialogue_line = dialogue_line
	_label.seconds_per_step = SECONDS_PER_STEP

	var plays_typing_sound := typing_sound != null
	if plays_typing_sound:
		SfxPlayer.play_ambient(typing_sound, TYPING_SOUND_FADE_SECONDS)

	_label.type_out()
	await _label.finished_typing

	if plays_typing_sound:
		SfxPlayer.stop_ambient(TYPING_SOUND_FADE_SECONDS)

	## Même son que les autres "grandes révélations" du jeu (voir
	## SfxPlayer.MAJOR_REVEAL_SFX, desktop.gd/vault_section.gd) — le moment où
	## le texte affiche enfin le nom du jeu est bien une de ces révélations.
	SfxPlayer.play(SfxPlayer.MAJOR_REVEAL_SFX)

	await get_tree().create_timer(CONTINUE_HINT_DELAY_SECONDS).timeout
	_continue_hint.show()
	_can_continue = true


## Un clic termine instantanément la frappe en cours (comme TerminalConsole/
## ConversationView), ou fait passer à la suite une fois le texte entier
## affiché et l'indicateur visible.
func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _label.is_typing:
		_label.skip_typing()
	elif _can_continue:
		_finish()


func _finish() -> void:
	_can_continue = false
	if music != null:
		MusicPlayer.stop(music_fade_seconds)
	closed.emit()
	queue_free()
