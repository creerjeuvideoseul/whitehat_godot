extends Control
## Cutscene played before login: swaps a full-screen background per dialogue
## line (called from intro.dialogue via `do change_background("...")`) while
## Dialogue Manager drives the bottom textbox. Ends on a simulated OS boot
## terminal, then hands off to the login screen.

const INTRO_DIALOGUE: DialogueResource = preload("res://dialogue/intro.dialogue")
const DIALOGUE_BALLOON := "res://scenes/dialogue/dialogue_balloon.tscn"
const TERMINAL_CONSOLE := preload("res://scenes/ui/terminal_console.tscn")
const INTRO_MUSIC := preload("res://assets/audio/shadowsandechoes-breaking-news-trailer-intro-orchester-news-318936.mp3")

const MUSIC_FADE_SECONDS := 1.0
## Durée du fondu enchaîné (crossfade) entre deux images, façon Ren'Py.
const DISSOLVE_SECONDS := 0.15

## Préchargées (pas construites depuis un chemin en runtime) pour que
## déplacer ces fichiers dans l'éditeur garde ces références à jour, comme
## c'est déjà le cas pour les scènes/ressources — un simple chemin en
## "dossier + nom + extension" n'a pas ce suivi, ce qui a déjà cassé cet
## écran silencieusement la dernière fois que les images ont bougé.
const BACKGROUNDS := {
	"wh_intro_fille_tele2": preload("res://assets/images_intro/wh_intro_fille_tele2.webp"),
	"wh_show_television_triste3": preload("res://assets/images_intro/wh_show_television_triste3.webp"),
	"wh_intro_femme_colere2": preload("res://assets/images_intro/wh_intro_femme_colere2.webp"),
	"wh_show_television_homme1": preload("res://assets/images_intro/wh_show_television_homme1.webp"),
	"wh_avec_ordi_quantique": preload("res://assets/images_intro/wh_avec_ordi_quantique.webp"),
	"wh_intro_femme_tourne_oeil": preload("res://assets/images_intro/wh_intro_femme_tourne_oeil.webp"),
	"wh_show_television_homme3": preload("res://assets/images_intro/wh_show_television_homme3.webp"),
	"wh_show_television_enerve2": preload("res://assets/images_intro/wh_show_television_enerve2.webp"),
	"wh_show_television_homme2": preload("res://assets/images_intro/wh_show_television_homme2.webp"),
	"wh_show_television_homme_enerve": preload("res://assets/images_intro/wh_show_television_homme_enerve.webp"),
}

@onready var _background: TextureRect = %Background
@onready var _background_incoming: TextureRect = %BackgroundIncoming

var _balloon: DialogueBalloon
var _dissolve_tween: Tween

## Un "cadre" par ligne de dialogue déjà affichée (image + personnage +
## texte), dans l'ordre. Alimente le retour en arrière à la molette —
## purement une consultation en lecture seule, l'état réel du dialogue
## (DialogueManager) n'est jamais rembobiné.
var _history: Array[Dictionary] = []
## Index du cadre actuellement affiché dans _history. Toujours sur le
## dernier cadre (la ligne live) tant que le joueur ne remonte pas.
var _history_index: int = -1


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	_balloon = DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, INTRO_DIALOGUE)
	_balloon.character_name_colors = { "Gilles": Palette.TEXT_BLUE_ACCENT }
	_balloon.dialogue_line_shown.connect(_on_dialogue_line_shown)

	MusicPlayer.play(INTRO_MUSIC, MUSIC_FADE_SECONDS)


## Called from intro.dialogue as `do change_background("wh_intro_fille_tele2")`.
## Fait un fondu enchaîné (dissolve) vers la nouvelle image plutôt qu'un
## changement brutal, façon Ren'Py.
##
## Ne bloque pas (pas de `await`) volontairement : DialogueManager traite
## chaque `do ...` comme une mutation, et DialogueBalloon cache le cadre si
## aucune nouvelle ligne n'arrive dans les 0.1s qui suivent (mutation_cooldown,
## pensé pour un `do` en toute fin de conversation sans texte après). Attendre
## ici les DISSOLVE_SECONDS (0.15s) dépasse ce délai et fait clignoter le
## cadre à chaque image — le fondu tourne donc en tâche de fond pendant que
## la ligne suivante s'enchaîne normalement.
func change_background(image_name: String) -> void:
	if not BACKGROUNDS.has(image_name):
		push_warning("Introduction: image manquante '%s'" % image_name)
		return

	var texture: Texture2D = BACKGROUNDS[image_name]
	if _dissolve_tween and _dissolve_tween.is_valid():
		_dissolve_tween.kill()

	_background_incoming.texture = texture
	_background_incoming.modulate.a = 0.0
	_dissolve_tween = create_tween()
	_dissolve_tween.tween_property(_background_incoming, "modulate:a", 1.0, DISSOLVE_SECONDS)
	_dissolve_tween.tween_callback(_on_dissolve_finished.bind(texture))


func _on_dissolve_finished(texture: Texture2D) -> void:
	_background.texture = texture
	_background_incoming.modulate.a = 0.0


func _on_dialogue_line_shown(character: String, text: String) -> void:
	_history.append({ "background": _background.texture, "character": character, "text": text })
	_history_index = _history.size() - 1


## Molette haut = une image en arrière, molette bas = une image en avant —
## bloqué à l'historique déjà vu, en lecture seule (voir _history plus haut).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rewind(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rewind(1)


func _rewind(step: int) -> void:
	var target_index: int = _history_index + step
	if target_index < 0 or target_index >= _history.size():
		return

	_history_index = target_index
	var frame: Dictionary = _history[_history_index]
	_background.texture = frame.background

	if _history_index == _history.size() - 1:
		_balloon.resume_live_line()
	else:
		_balloon.show_history_line(frame.character, frame.text)


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if resource != INTRO_DIALOGUE:
		return

	MusicPlayer.stop(MUSIC_FADE_SECONDS)

	await SceneTransition.fade_out()
	_background.hide()
	_background_incoming.hide()
	SceneTransition.fade_in()

	await _play_boot_terminal()

	await SceneTransition.fade_out()
	get_tree().change_scene_to_file("res://scenes/login.tscn")
	SceneTransition.fade_in()


## Simule le démarrage du système d'exploitation avant la page de connexion,
## dans la même fenêtre-terminal réutilisable que pour Jean Ranoud (voir
## desktop.gd) — ici sans bouton "Fermer" : un écran de boot se regarde, il
## ne se ferme pas manuellement.
func _play_boot_terminal() -> void:
	var console: TerminalConsole = TERMINAL_CONSOLE.instantiate()
	console.title = "TERMINAL_BOOT_TITLE"
	console.show_close_button = false
	console.lines = _build_boot_lines()
	add_child(console)
	await console.closed


func _build_boot_lines() -> Array[TerminalLine]:
	var prompt := "#%s" % Palette.BORDER_ACCENT.to_html(false)
	var accent := "#%s" % Palette.TEXT_ACCENT.to_html(false)
	var danger := "#%s" % Palette.TEXT_DANGER.to_html(false)
	var muted := "#%s" % Palette.CONSOLE_TEXT.to_html(false)

	var lines: Array[TerminalLine] = []
	lines.append(_boot_line(prompt, accent, muted, "SYSTEM:", "Initializing White Hat OS v0.9.4..."))
	lines.append(_boot_line(prompt, accent, muted, "SYSTEM:", "Decrypting local database with master private key..."))
	lines.append(_boot_line(prompt, accent, muted, "SYSTEM:", "Establishing handshakes with cellular towers..."))
	lines.append(_boot_line(prompt, danger, muted, "LOGS:", "Security warning detected. HAL_SYS monitor has bypass access."))
	lines.append(_boot_line(prompt, accent, muted, "SYSTEM:", "Translation..."))
	lines.append(TerminalLine.text_line("[color=%s]>>[/color] [color=%s]%s[/color]" % [prompt, muted, tr("TERMINAL_BOOT_STARTING_SESSION")]))
	return lines


func _boot_line(prompt: String, tag_color: String, text_color: String, tag: String, message: String) -> TerminalLine:
	return TerminalLine.text_line("[color=%s]>>[/color] [color=%s]%s[/color][color=%s] %s[/color]" % [prompt, tag_color, tag, text_color, message])
