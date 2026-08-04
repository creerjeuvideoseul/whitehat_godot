extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). Owns spawning windows into WindowLayer, the area reserved between
## the header and footer, and wires each window's minimize button to the
## footer's taskbar. The header/footer otherwise manage themselves
## (desktop_header.gd, desktop_footer.gd).

const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const CLUE_BOARD_WINDOW := preload("res://scenes/desktop/windows/clue_board_window.tscn")
const TERMINAL_CONSOLE := preload("res://scenes/ui/terminal_console.tscn")
## The mission the "Indice" button currently opens. No mission-selection UI
## exists yet, so this is hardcoded for now — same simplification the chat
## contacts already make (see JEAN_REVEAL_DELAY_SECONDS below).
const CURRENT_MISSION_ID := 1
const ANONGHOST_AVATAR := preload("res://assets/avatar/anonghost_avatar.png")
const ANONGHOST_DIALOGUE: DialogueResource = preload("res://dialogue/anonghost_intro.dialogue")
const JEAN_AVATAR := preload("res://assets/avatar/portrait_jean.webp")
const JEAN_DIALOGUE: DialogueResource = preload("res://dialogue/jean_intro.dialogue")

## The chat window auto-opens on desktop load for now — there's no "how do
## you open a window" system yet (icons, notifications, ...), so this is
## provisional wiring to keep everything testable end to end.

## Laisse le joueur "seul" sur le bureau un court instant avant que la
## fenêtre de discussion n'apparaisse, plutôt que de la voir surgir
## immédiatement à l'arrivée sur le bureau.
const DESKTOP_ENTRY_DELAY_SECONDS := 3.0

## Jean only shows up in the sidebar once AnonGhost's briefing is over, with
## a short pause first so the two don't blur together.
const JEAN_REVEAL_DELAY_SECONDS := 1.0

@onready var _window_layer: Control = %WindowLayer
@onready var _footer: Control = %DesktopFooter
@onready var _header: DesktopHeader = %DesktopHeader

## Kept so pressing "Indice" a second time re-shows the same window (and its
## already-unlocked state) instead of stacking duplicates — it can't be
## closed, only minimized, so a second instance would linger forever.
var _clue_board_window: ClueBoardWindow = null
## Last title it minimized under, so re-showing it via the header button (as
## opposed to its own taskbar icon) can clear that now-stale icon.
var _clue_board_window_title: String = ""


func _ready() -> void:
	_header.clue_button_pressed.connect(_on_clue_button_pressed)
	await get_tree().create_timer(DESKTOP_ENTRY_DELAY_SECONDS).timeout
	_open_window(_build_chat_window())


func _build_chat_window() -> ChatWindow:
	var window: ChatWindow = CHAT_WINDOW.instantiate()
	window.contacts = [_build_anonghost_contact()]
	# Si la conversation avec AnonGhost est déjà terminée (reprise d'une
	# sauvegarde), le signal contact_conversation_finished ne se redéclenchera
	# jamais — _replay_saved_log() ne le réémet pas. Jean doit donc déjà être
	# dans la liste initiale plutôt que d'attendre ce signal.
	if SaveManager.is_conversation_complete("anonghost"):
		window.contacts.append(_build_jean_contact())
	window.contact_conversation_finished.connect(func(contact_id: String) -> void:
		if contact_id == "anonghost":
			await get_tree().create_timer(JEAN_REVEAL_DELAY_SECONDS).timeout
			window.add_contact(_build_jean_contact())
		elif contact_id == "jean_ranoud":
			_play_jean_dump_terminal()
	)
	return window


func _build_anonghost_contact() -> ChatContact:
	var contact := ChatContact.new()
	contact.contact_id = "anonghost"
	contact.contact_name = "AnonGhost"
	contact.avatar = ANONGHOST_AVATAR
	contact.dialogue_resource = ANONGHOST_DIALOGUE
	return contact


## Jean's messages use a distinct blue tint (ChatContact.bubble_color) so
## the two contacts stay visually distinguishable inside the same window —
## the window itself keeps the default green chrome shared by all contacts.
func _build_jean_contact() -> ChatContact:
	var contact := ChatContact.new()
	contact.contact_id = "jean_ranoud"
	contact.contact_name = "Jean Ranoud"
	contact.avatar = JEAN_AVATAR
	contact.dialogue_resource = JEAN_DIALOGUE
	contact.bubble_color = Palette.BUBBLE_BLUE
	return contact


## Once Jean's call ends, simulate the phone-dump-and-analysis sequence as a
## full-screen terminal transition (see TerminalConsole) before handing off
## to the investigation itself.
func _play_jean_dump_terminal() -> void:
	# Point de sauvegarde explicite juste avant le terminal : si le joueur
	# quitte pendant/juste après l'animation, "Continuer" le ramène ici sans
	# rejouer la discussion avec Jean (déjà marquée complète par ailleurs).
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())

	var console: TerminalConsole = TERMINAL_CONSOLE.instantiate()
	console.lines = _build_jean_dump_lines()
	console.closed.connect(_on_jean_dump_terminal_closed)
	add_child(console)


## TODO: une fois la scène d'enquête fournie, l'enchaîner ici (fade +
## change_scene_to_file) — c'est l'unique point d'extension pour la suite.
func _on_jean_dump_terminal_closed() -> void:
	pass


## Script de la séquence "hack" simulant le rapatriement + l'analyse OSINT
## des données du téléphone d'Alizée. Les commandes/sorties système restent
## dans leur jargon technique quelle que soit la langue (un vrai terminal ne
## se traduit pas) — seules les deux phrases en langage naturel passent par
## ui.csv, comme le reste du chrome de l'interface.
func _build_jean_dump_lines() -> Array[TerminalLine]:
	var prompt := "#%s" % Palette.BORDER_ACCENT.to_html(false)
	var normal := "#%s" % Palette.TEXT_NORMAL.to_html(false)
	var muted := "#%s" % Palette.CONSOLE_TEXT.to_html(false)
	var accent := "#%s" % Palette.TEXT_ACCENT.to_html(false)

	var lines: Array[TerminalLine] = []
	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]ssh-agent sh -c 'ssh-add ~/.ssh/jean_rsa; ssh jean@203.0.113.45'[/color]" % [prompt, normal]))
	lines.append(TerminalLine.text_line("[color=%s][color=%s][+][/color] Authenticating against remote host 203.0.113.45:22... Connection established.[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s]jean@203.0.113.45:~$[/color] [color=%s]scp ./backups/mobile_dump_2026.tar.gz user@192.168.1.12:~/workspace/[/color]" % [prompt, normal]))
	lines.append(TerminalLine.progress_line("mobile_dump_2026.tar.gz", 3420, "48.2MB/s", "01:11"))
	lines.append(TerminalLine.text_line("[color=%s]jean@203.0.113.45:~$[/color] [color=%s]exit[/color]" % [prompt, normal]))
	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]tar -xzvf ~/workspace/mobile_dump_2026.tar.gz -C ~/workspace/raw_data/[/color]" % [prompt, normal]))
	lines.append(TerminalLine.text_line("[color=%s]unpacking raw_dump.bin... [color=%s]DONE[/color] (42,891 blocks processed)[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]./bin/parser --input ~/workspace/raw_data/ --filter-level deep[/color]" % [prompt, normal]))
	lines.append(TerminalLine.text_line("[color=%s][color=%s][SYS][/color] Initializing OSINT heuristic analyzer v4.2...[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s][color=%s][SYS][/color] Parsing SQLite databases, app cache, and system logs...[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s][color=%s][SYS][/color] Stripping telemetry data & telemetry noise... (89%% discarded)[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s][color=%s][SYS][/color] Rebuilding timeline matrix... [color=%s]DONE[/color][/color]" % [muted, accent, accent]))
	lines.append(TerminalLine.text_line("[color=%s][SUCCESS] %s[/color]" % [accent, tr("TERMINAL_JEAN_DUMP_SUCCESS")]))
	lines.append(TerminalLine.text_line("[color=%s]%s[/color]" % [muted, tr("TERMINAL_JEAN_DUMP_LOADING")]))
	return lines


## Untyped on purpose: ChatWindow and ClueBoardWindow both expose the same
## minimize_requested(window, window_title) signal by convention, but don't
## share a base class — a Control-typed parameter would make the static
## checker reject a signal it can't see on Control itself.
func _open_window(window) -> void:
	window.minimize_requested.connect(_on_window_minimize_requested)
	_window_layer.add_child(window)


func _on_window_minimize_requested(window: Control, window_title: String) -> void:
	if window == _clue_board_window:
		_clue_board_window_title = window_title
	_footer.add_minimized_window(window_title, func() -> void: window.show())


## "Indice" always reopens the same board so its layout/unlocked state isn't
## rebuilt from scratch every click — only the first press instantiates it.
## It has no close button (only minimize), so a second instance would linger
## on screen forever if we let one get created.
func _on_clue_button_pressed() -> void:
	if is_instance_valid(_clue_board_window):
		_footer.remove_minimized_window(_clue_board_window_title)
		_clue_board_window.show()
		return

	_clue_board_window = CLUE_BOARD_WINDOW.instantiate()
	_clue_board_window.mission_id = CURRENT_MISSION_ID
	_open_window(_clue_board_window)
