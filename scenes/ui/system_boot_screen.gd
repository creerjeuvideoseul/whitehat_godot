extends Control
class_name SystemBootScreen
## Simulation de démarrage du système d'exploitation (boot W_HAT_OS) — la
## toute première fenêtre système du jeu, juste après la cutscene
## d'introduction et avant l'écran de connexion (voir introduction.gd). Scène
## à part (plutôt qu'une méthode privée d'introduction.gd, où elle vivait
## avant) pour pouvoir être rejouée plus tard dans la partie (ex. un "reboot"
## du système) sans dupliquer le script de lignes ni le réglage plein écran.
##
## Plein écran (TerminalConsole.box_size = taille du viewport) plutôt que la
## boîte centrée habituelle de TerminalConsole (voir box_size) : un écran de
## boot occupe tout l'affichage, contrairement aux terminaux "fenêtre" du
## bureau (dump de Jean, connexion RDP...) qui gardent leur taille par défaut.

signal closed

const TERMINAL_CONSOLE := preload("res://scenes/ui/terminal_console.tscn")
## Joué à l'ouverture de cette fenêtre système — un seul coup, pas une
## ambiance, pour marquer la bascule "cinématique/précédent -> interface
## système".
const BOOT_SYSTEM_SFX := preload("res://assets/audio/sound/juniorsoundays-motion-amp-tansitions-02-527730.mp3")


## Instancie le terminal de boot plein écran, attend qu'il se termine (auto-
## fermeture, show_close_button = false : un écran de boot se regarde, il ne
## se ferme pas manuellement), puis émet `closed` et se libère.
func _ready() -> void:
	SfxPlayer.play(BOOT_SYSTEM_SFX)
	var console: TerminalConsole = TERMINAL_CONSOLE.instantiate()
	console.title = "TERMINAL_BOOT_TITLE"
	console.show_close_button = false
	console.box_size = get_viewport_rect().size
	## +5 partout, même jeu de couleurs (voir échange avec l'utilisateur) —
	## voir TerminalConsole.font_size_boost, qui ne touche que cette instance
	## (dump de Jean, connexion RDP... gardent leur taille normale).
	console.font_size_boost = 5
	console.lines = _build_boot_lines()
	add_child(console)
	await console.closed
	closed.emit()
	queue_free()


func _build_boot_lines() -> Array[TerminalLine]:
	var prompt := "#%s" % Palette.BORDER_ACCENT.to_html(false)
	var accent := "#%s" % Palette.TEXT_ACCENT.to_html(false)
	var muted := "#%s" % Palette.CONSOLE_TEXT.to_html(false)

	var lines: Array[TerminalLine] = []
	lines.append(_wh_line(prompt, accent, muted, "W_HAT_OS Kernel 6.8.4 initialized successfully."))
	lines.append(_wh_line(prompt, accent, muted, "Connecting to proxy standard secure gateways on port 3000..."))
	lines.append(_wh_line(prompt, accent, muted, "Loading virtual environment: RESOLUTION=2560x1440, MULTI_VIEW_SPA=ON."))
	lines.append(_wh_line(prompt, accent, muted, "Bypassing Sentinelle Quantique active detection nodes..."))
	lines.append(_wh_line(prompt, accent, muted, "ESTABLISHING METADATA DISPATCHER [OK]"))
	lines.append(_wh_line(prompt, accent, muted, "Boot sequence completed. Launching White Hat OS command center..."))
	lines.append(_boot_line(prompt, accent, muted, "SYSTEM:", "Translation..."))
	lines.append(TerminalLine.text_line("[color=%s]>>[/color] [color=%s]%s[/color]" % [prompt, muted, tr("TERMINAL_BOOT_STARTING_SESSION")]))
	return lines


func _boot_line(prompt: String, tag_color: String, text_color: String, tag: String, message: String) -> TerminalLine:
	return TerminalLine.text_line("[color=%s]>>[/color] [color=%s]%s[/color][color=%s] %s[/color]" % [prompt, tag_color, tag, text_color, message])


## Même forme que _boot_line mais avec le préfixe "W_HAT >" utilisé par le
## log de boot, sans tag ":" intermédiaire.
func _wh_line(prompt: String, tag_color: String, text_color: String, message: String) -> TerminalLine:
	return TerminalLine.text_line("[color=%s]W_HAT[/color] [color=%s]>[/color] [color=%s]%s[/color]" % [tag_color, prompt, text_color, message])
