extends Control
## Cutscene played before login: swaps a full-screen background per dialogue
## line (called from intro.dialogue via `do change_background("...")`) while
## Dialogue Manager drives the bottom textbox. Ends on a simulated OS boot
## terminal, then hands off to the login screen.

const INTRO_DIALOGUE: DialogueResource = preload("res://dialogue/intro.dialogue")
const DIALOGUE_BALLOON := "res://scenes/dialogue/dialogue_balloon.tscn"
const INTRO_MUSIC := preload("res://assets/audio/shadowsandechoes-breaking-news-trailer-intro-orchester-news-318936.mp3")
## Boot OS plein écran juste après cette cutscene, avant l'écran de connexion
## — voir _play_boot_terminal et system_boot_screen.gd (scène à part plutôt
## qu'ici : rejouable plus tard dans la partie, ex. un "reboot" du système).
const SYSTEM_BOOT_SCREEN := preload("res://scenes/ui/system_boot_screen.tscn")
## Monologue de rédemption ("Je veux être un... WHITE HAT"), joué écran noir
## juste après le JT et avant le boot du système — voir _play_monologue().
## Partage MUSIC_FADE_SECONDS (1s) ci-dessous avec la musique du JT.
const MONOLOGUE_SCREEN := preload("res://scenes/monologue_screen.tscn")
const MONOLOGUE_MUSIC := preload("res://assets/audio/soundreality-cinematic-tension-2-504666.mp3")

const MUSIC_FADE_SECONDS := 1.0
## Fondu au noir entre l'écran du monologue et la fenêtre système (voir
## _on_dialogue_ended) — plus court que SceneTransition.DEFAULT_FADE_SECONDS
## (0.6s, retour joueur : 1.4s traînait trop) : une coupure nette entre deux
## temps du jeu (l'intime du monologue vs le système qui démarre), pas un
## enchaînement lent.
const MONOLOGUE_TO_BOOT_FADE_SECONDS := 0.5
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
## Habillage "JT en direct" superposé à toutes les images de cette cutscene
## uniquement (voir introduction.tscn) — jamais réutilisé par les dialogues
## suivants du jeu, qui passent par chat_window/conversation_view et non par
## cette scène.
@onready var _live_badge: Control = %LiveBadge
@onready var _flash_info_banner: Control = %FlashInfoBanner

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
	_balloon.character_name_colors = { "Gilles de la Touret": Palette.TEXT_BLUE_ACCENT }
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
##
## _input() plutôt que _unhandled_input() : la balloon de dialogue couvre tout
## l'écran avec mouse_filter = STOP (nécessaire pour capturer les clics qui
## avancent le dialogue), ce qui arrête tout événement souris avant qu'il
## n'atteigne _unhandled_input — la molette n'arrivait donc jamais ici.
## _input() est appelé avant le passage GUI, donc insensible à ce filtre.
##
## Un clic gauche pendant la consultation de l'historique (pas encore revenu
## à la ligne live) avance d'un cran, façon Ren'Py — plutôt que de ne rien
## faire (DialogueBalloon.is_waiting_for_input reste à false tant qu'on
## consulte l'historique, donc son propre clic-pour-avancer est inopérant ici,
## voir dialogue_balloon.gd). Sans risque de sauter un mutate/indice/save
## puisque intro.dialogue n'en déclenche aucun.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rewind(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rewind(1)
		elif event.button_index == MOUSE_BUTTON_LEFT and _is_browsing_history():
			get_viewport().set_input_as_handled()
			_rewind(1)


func _is_browsing_history() -> bool:
	return _history_index >= 0 and _history_index < _history.size() - 1


func _rewind(step: int) -> void:
	var target_index: int = _history_index + step
	if target_index < 0 or target_index >= _history.size():
		return

	# Ne pas quitter la ligne live tant qu'elle est en train de se taper :
	# show_history_line() écrase le texte du DialogueLabel pendant que sa
	# coroutine de frappe (type_out()/await finished_typing) est encore en
	# cours dessus, ce qui la fait se terminer prématurément sur un texte qui
	# n'est plus le bon — et laisse ensuite le dialogue coincé (is_waiting_for_input
	# jamais restauré), le clic gauche ne faisant plus rien.
	var is_live: bool = _history_index == _history.size() - 1
	if is_live and step < 0 and _balloon.dialogue_label.is_typing:
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
	_live_badge.hide()
	_flash_info_banner.hide()
	SceneTransition.fade_in()

	await _play_monologue()

	await SceneTransition.fade_out(MONOLOGUE_TO_BOOT_FADE_SECONDS)
	SceneTransition.fade_in(MONOLOGUE_TO_BOOT_FADE_SECONDS)

	await _play_boot_terminal()

	# Effet "extinction CRT" pour la fermeture de l'ecran systeme (voir
	# SceneTransition.crt_off()), puis fade_in() classique pour l'arrivee du
	# login.
	await SceneTransition.crt_off()
	get_tree().change_scene_to_file("res://scenes/login.tscn")
	SceneTransition.fade_in()


## Monologue de rédemption, écran noir avant le boot du système — voir
## MonologueScreen. "WHITE HAT"/"Black Hats" sont injectés en code (couleur
## Palette.TEXT_ACCENT/TEXT_DANGER, police +5 par rapport au reste du texte)
## plutôt que codés en dur dans le texte traduit, pour ne pas coupler
## translations/ui.csv à une couleur/taille.
func _play_monologue() -> void:
	var accent := "#%s" % Palette.TEXT_ACCENT.to_html(false)
	var danger := "#%s" % Palette.TEXT_DANGER.to_html(false)
	var blue := "#%s" % Palette.TEXT_BLUE_ACCENT.to_html(false)
	var white := "#%s" % Palette.TEXT_NORMAL.to_html(false)
	var whitehat := "[font_size=%d][b][color=%s]WHITE HAT[/color][/b][/font_size]" % [Palette.SIZE_LARGE + 5, accent]
	var black_hats := "[font_size=%d][b][color=%s]Black Hats[/color][/b][/font_size]" % [Palette.SIZE_LARGE + 5, danger]
	## Même mise en valeur que WHITE HAT (taille, gras) mais en bleu (voir
	## Palette.TEXT_BLUE_ACCENT, déjà utilisé pour Gilles de la Touret plus tôt
	## dans cette même cutscene) — RelayGhost est un nom propre, injecté en
	## code comme les deux autres plutôt que codé en dur dans le texte traduit.
	var relayghost := "[font_size=%d][b][color=%s]RelayGhost[/color][/b][/font_size]" % [Palette.SIZE_LARGE + 5, blue]
	## Même mise en valeur que WHITE HAT/RelayGhost mais en blanc (Palette.
	## TEXT_NORMAL). Contrairement aux deux autres, "rédemption" n'est pas un
	## nom propre : le mot lui-même reste traduit via sa propre clé ui.csv
	## (INTRO_MONOLOGUE_6_REDEMPTION_WORD) plutôt que codé en dur, seule la
	## mise en forme vient d'ici.
	var redemption := "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [Palette.SIZE_LARGE + 5, white, tr("INTRO_MONOLOGUE_6_REDEMPTION_WORD")]
	var text := "%s\n%s\n%s\n\n%s\n\n%s\n%s\n\n%s\n\n%s" % [
		tr("INTRO_MONOLOGUE_1"), tr("INTRO_MONOLOGUE_2") % black_hats, tr("INTRO_MONOLOGUE_3"),
		tr("INTRO_MONOLOGUE_4"),
		tr("INTRO_MONOLOGUE_5"), tr("INTRO_MONOLOGUE_6") % redemption,
		tr("INTRO_MONOLOGUE_7") % relayghost,
		tr("INTRO_MONOLOGUE_8") % whitehat,
	]

	var monologue: MonologueScreen = MONOLOGUE_SCREEN.instantiate()
	monologue.text = text
	monologue.music = MONOLOGUE_MUSIC
	monologue.music_fade_seconds = MUSIC_FADE_SECONDS
	monologue.typing_sound = SfxPlayer.TERMINAL_TYPING_SFX
	add_child(monologue)
	await monologue.closed


## Simule le démarrage du système d'exploitation avant la page de connexion —
## voir system_boot_screen.gd pour le détail (plein écran, script des lignes,
## SFX).
func _play_boot_terminal() -> void:
	var boot_screen: SystemBootScreen = SYSTEM_BOOT_SCREEN.instantiate()
	add_child(boot_screen)
	await boot_screen.closed
