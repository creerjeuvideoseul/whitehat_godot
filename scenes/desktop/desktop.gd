extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). Owns spawning windows into WindowLayer, the area reserved between
## the header and footer, and wires each window's minimize button to the
## footer's taskbar. The header/footer otherwise manage themselves
## (desktop_header.gd, desktop_footer.gd).

const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const CLUE_BOARD_WINDOW := preload("res://scenes/desktop/windows/clue_board_window.tscn")
const OSINT_WINDOW := preload("res://scenes/desktop/windows/osint_window.tscn")
const TERMINAL_CONSOLE := preload("res://scenes/ui/terminal_console.tscn")
const PLAYER_THOUGHT := preload("res://scenes/ui/player_thought.tscn")
const MATRIX_RAIN := preload("res://scenes/ui/matrix_rain.tscn")
const ALIZEE_PHONE := preload("res://scenes/desktop/phone/alizee_phone.tscn")
## Une scène par icône du téléphone — voir AlizeePhone.icon_pressed. Volontairement
## non génériques : chaque section aura son propre gameplay à terme (SMS, mail,
## galerie, coffre-fort n'ont rien en commun), donc pas de scène "placeholder"
## partagée à factoriser pour l'instant.
const PHONE_SECTIONS := {
	AlizeePhone.SECTION_SMS: preload("res://scenes/desktop/phone/sections/sms_section.tscn"),
	AlizeePhone.SECTION_MAIL: preload("res://scenes/desktop/phone/sections/mail_section.tscn"),
	AlizeePhone.SECTION_GALLERY: preload("res://scenes/desktop/phone/sections/gallery_section.tscn"),
	AlizeePhone.SECTION_VAULT: preload("res://scenes/desktop/phone/sections/vault_section.tscn"),
}
## Durée du glissement + fondu d'apparition du téléphone d'Alizée.
const PHONE_REVEAL_SECONDS := 0.6
## Décalage de départ (hors écran vers la gauche) pour l'effet de glissement.
const PHONE_REVEAL_SLIDE_OFFSET := 120.0
## Durée/amplitude du glissement de rangement de la fenêtre de chat vers la
## barre des tâches (voir _minimize_window_with_slide), même esprit que
## PHONE_REVEAL_SECONDS/OFFSET mais en sens inverse (vers le bas).
const CHAT_MINIMIZE_SLIDE_SECONDS := 0.5
const CHAT_MINIMIZE_SLIDE_OFFSET := 80.0
## The mission the "Indice" button currently opens. No mission-selection UI
## exists yet, so this is hardcoded for now — same simplification the chat
## contacts already make (see JEAN_REVEAL_DELAY_SECONDS below).
const CURRENT_MISSION_ID := 1
const ANONGHOST_AVATAR := preload("res://assets/avatar/anonghost_avatar.png")
const ANONGHOST_DIALOGUE: DialogueResource = preload("res://dialogue/anonghost_intro.dialogue")
const JEAN_AVATAR := preload("res://assets/avatar/portrait_jean.webp")
const JEAN_DIALOGUE: DialogueResource = preload("res://dialogue/jean_intro.dialogue")
## Bruitage de frappe joué pendant le terminal simulant le rapatriement des
## données du téléphone d'Alizée (voir _play_jean_dump_terminal) — le joueur
## y "tape" des commandes, contrairement au boot système après l'intro qui ne
## reçoit volontairement pas ce son (voir Introduction).
const JEAN_DUMP_TYPING_SOUND := preload("res://assets/audio/sound/virtual_vibes-fast-keyboard-typing-423436.mp3")

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
@onready var _phone_section_host: Control = %PhoneSectionHost

## Kept so pressing "Indice" a second time re-shows the same window (and its
## already-unlocked state) instead of stacking duplicates — it can't be
## closed, only minimized, so a second instance would linger forever.
var _clue_board_window: ClueBoardWindow = null
## Last title it minimized under, so re-showing it via the header button (as
## opposed to its own taskbar icon) can clear that now-stale icon.
var _clue_board_window_title: String = ""

## Même principe que _clue_board_window : une seule fenêtre OSINT réutilisée
## d'une recherche à l'autre (jamais de doublon dans la taskbar), son contenu
## étant entièrement remplacé à chaque recherche par OsintWindow.search().
var _osint_window: OsintWindow = null
var _osint_window_title: String = ""

## Le téléphone d'Alizée reste affiché en permanence une fois révélé — pas de
## fermeture/minimisation prévue, donc une seule instance possible (utile
## surtout pour éviter d'en recréer une seconde au retour d'une sauvegarde).
var _alizee_phone: AlizeePhone = null

## Référence à la fenêtre de discussion AnonGhost/Jean ouverte au tout début
## du bureau — gardée pour pouvoir la ranger (voir _minimize_window_with_slide)
## une fois le téléphone d'Alizée sur le point d'apparaître.
var _chat_window: ChatWindow = null


func _ready() -> void:
	_header.clue_button_pressed.connect(_on_clue_button_pressed)
	_header.osint_search_requested.connect(_on_osint_search_requested)

	# Debug only (voir Settings.IS_PRODUCTION) : le bouton "revenir avant la
	# fin de Jean" du footer a chargé un instantané séparé juste avant cet
	# appel puis rechargé cette scène — la conversation avec Jean n'y est
	# volontairement pas marquée complète (capturée avant sa vraie fin), donc
	# on rejoue directement le terminal plutôt que de suivre le chemin normal
	# ci-dessous (qui rejouerait tout le dialogue de Jean depuis le début).
	if SaveManager.consume_debug_replay_jean_terminal():
		_chat_window = _build_chat_window()
		_open_window(_chat_window)
		_chat_window.hide()
		_on_window_minimize_requested(_chat_window, tr("CHAT_WINDOW_TITLE"))
		_play_jean_dump_terminal()
		return

	# Reprise d'une sauvegarde postérieure à l'appel de Jean : le téléphone
	# doit déjà être là, sans rejouer son animation d'apparition.
	var jean_done := SaveManager.is_conversation_complete("jean_ranoud")
	if jean_done:
		_reveal_alizee_phone(false)
		# Sans ça, la conversation AnonGhost/Jean n'était accessible que
		# pendant la session où elle s'est terminée : desktop.gd repart de
		# zéro à chaque chargement de sauvegarde et ne la recréait jamais
		# après coup, la rendant introuvable (aucune icône dans la taskbar).
		# On la rouvre donc ici aussi, déjà entièrement déroulée (voir
		# ConversationView._replay_saved_log()) plutôt que rejouée en direct,
		# et sans le délai d'entrée qui n'a de sens qu'à la toute première
		# arrivée sur le bureau. Réduite par défaut : à la reprise, le
		# téléphone d'Alizée est le vrai point d'entrée, la conversation
		# reste à un clic dans la taskbar sans s'imposer par-dessus.
		_chat_window = _build_chat_window()
		_open_window(_chat_window)
		_chat_window.hide()
		_on_window_minimize_requested(_chat_window, tr("CHAT_WINDOW_TITLE"))
		return

	# L'ouverture automatique après un délai ne doit surprendre que tant qu'il
	# reste quelque chose à découvrir dans le chat (première arrivée après
	# l'intro/login, ou reprise entre la fin d'AnonGhost et celle de Jean) —
	# pas une reprise après coup, où tout a déjà été lu et où seul le
	# téléphone d'Alizée reste à l'écran. Pas de is_conversation_complete("anonghost")
	# ici : ça stranderait le joueur qui reprend juste après AnonGhost, sans
	# autre moyen de rouvrir le chat pour parler à Jean (pas d'icône/taskbar
	# pour ça pour l'instant).
	# Immédiat, sans attendre le délai d'ouverture du chat ci-dessous —
	# seulement le tout premier contact, pas la reprise "entre AnonGhost et
	# Jean" couverte par cette même branche (voir commentaire ci-dessus), où
	# AnonGhost a déjà été rencontré lors d'une session précédente.
	if not SaveManager.is_conversation_complete("anonghost"):
		_show_player_thought(tr("THOUGHT_ANONGHOST_CONTACT"))

	await get_tree().create_timer(DESKTOP_ENTRY_DELAY_SECONDS).timeout
	_chat_window = _build_chat_window()
	_open_window(_chat_window)


## Petit encart "pensée du joueur" en bas de l'écran (voir player_thought.gd)
## — se montre et se referme tout seul, rien à garder côté appelant.
func _show_player_thought(text: String) -> void:
	var thought: PlayerThought = PLAYER_THOUGHT.instantiate()
	thought.text = text
	_window_layer.add_child(thought)


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
	console.typing_sound = JEAN_DUMP_TYPING_SOUND
	console.closed.connect(_on_jean_dump_terminal_closed)
	add_child(console)


## Une fois le terminal fermé : la fenêtre de chat (devenue accessoire, la
## conversation avec Jean est terminée) se range dans la barre des tâches,
## puis une pluie de caractères façon Matrix (voir MatrixRain) couvre le
## bureau central le temps de la bascule — évite le "cut" brutal terminal →
## téléphone. Remplace l'ancien fondu au noir (SceneTransition, toujours
## utilisé ailleurs pour les changements de scène) : si cet effet ne
## convenait pas, il suffit de remettre les deux lignes
## SceneTransition.fade_out/fade_in ici à la place de _play_matrix_rain_transition().
## Le téléphone d'Alizée, point d'entrée de l'enquête, apparaît ensuite avec
## sa propre animation.
func _on_jean_dump_terminal_closed() -> void:
	# .visible : si le joueur avait déjà réduit la fenêtre de lui-même avant
	# la fin de la discussion, un second rangement créerait un doublon dans
	# la barre des tâches (voir DesktopFooter.add_minimized_window, qui ne
	# déduplique pas par titre comme le font Indice/OSINT).
	if is_instance_valid(_chat_window) and _chat_window.visible:
		await _minimize_window_with_slide(_chat_window, tr("CHAT_WINDOW_TITLE"))

	await _play_matrix_rain_transition()
	_reveal_alizee_phone(true)


## N'affecte que WindowLayer (le bureau central) — le header/footer restent
## visibles, contrairement à SceneTransition qui couvre tout l'écran.
func _play_matrix_rain_transition() -> void:
	var rain: MatrixRain = MATRIX_RAIN.instantiate()
	_window_layer.add_child(rain)
	await rain.finished


## Glissement + fondu vers le bas (même esprit que _animate_phone_reveal,
## sens inverse) avant de ranger réellement la fenêtre — pour un rangement
## visible plutôt que la disparition instantanée du bouton "réduire".
func _minimize_window_with_slide(window: Control, window_title: String) -> void:
	var origin_y := window.position.y

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(window, "position:y", origin_y + CHAT_MINIMIZE_SLIDE_OFFSET, CHAT_MINIMIZE_SLIDE_SECONDS)
	tween.tween_property(window, "modulate:a", 0.0, CHAT_MINIMIZE_SLIDE_SECONDS)
	await tween.finished

	# Remis à l'état normal avant de cacher : la fenêtre doit réapparaître
	# pile comme avant, pas fondue/décalée, quand on la rouvre depuis la
	# barre des tâches.
	window.position.y = origin_y
	window.modulate.a = 1.0
	window.hide()
	_on_window_minimize_requested(window, window_title)


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
	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]ssh-agent sh -c 'ssh-add ~/.ssh/jean_rsa; ssh jean@203.0.113.45'[/color]" % [prompt, normal], true))
	lines.append(TerminalLine.text_line("[color=%s][color=%s][+][/color] Authenticating against remote host 203.0.113.45:22... Connection established.[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s]jean@203.0.113.45:~$[/color] [color=%s]scp ./backups/mobile_dump_2026.tar.gz user@192.168.1.12:~/workspace/[/color]" % [prompt, normal], true))
	lines.append(TerminalLine.progress_line("mobile_dump_2026.tar.gz", 3420, "48.2MB/s", "01:11"))
	lines.append(TerminalLine.text_line("[color=%s]jean@203.0.113.45:~$[/color] [color=%s]exit[/color]" % [prompt, normal], true))
	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]tar -xzvf ~/workspace/mobile_dump_2026.tar.gz -C ~/workspace/raw_data/[/color]" % [prompt, normal], true))
	lines.append(TerminalLine.text_line("[color=%s]unpacking raw_dump.bin... [color=%s]DONE[/color] (42,891 blocks processed)[/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]./bin/parser --input ~/workspace/raw_data/ --filter-level deep[/color]" % [prompt, normal], true))
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
	elif window == _osint_window:
		_osint_window_title = window_title
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


## Une recherche OSINT réutilise toujours la même fenêtre (jamais de doublon
## dans la taskbar) : elle se rouvre si elle était réduite, et son contenu
## précédent est systématiquement remplacé par le nouveau résultat.
func _on_osint_search_requested(query: String) -> void:
	if is_instance_valid(_osint_window):
		_footer.remove_minimized_window(_osint_window_title)
		_osint_window.show()
	else:
		_osint_window = OSINT_WINDOW.instantiate()
		_open_window(_osint_window)

	_osint_window.search(query)


## Instancie le téléphone d'Alizée à gauche du bureau (une seule fois — il
## n'a pas de fermeture/minimisation) et branche ses icônes sur le
## changement de section. `animate` est à false lors d'une reprise de
## sauvegarde : le téléphone doit être déjà là, pas en train d'apparaître.
func _reveal_alizee_phone(animate: bool) -> void:
	if is_instance_valid(_alizee_phone):
		return

	_alizee_phone = ALIZEE_PHONE.instantiate()
	_alizee_phone.icon_pressed.connect(_on_phone_icon_pressed)
	_window_layer.add_child(_alizee_phone)

	if animate:
		_animate_phone_reveal(_alizee_phone)


## Glissement + fondu depuis la gauche, dans le même esprit que le shake de
## ChatWindow (tween direct sur position/modulate, sans toucher aux ancres).
func _animate_phone_reveal(phone: Control) -> void:
	await get_tree().process_frame
	var target_x := phone.position.x
	phone.position.x = target_x - PHONE_REVEAL_SLIDE_OFFSET
	phone.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(phone, "position:x", target_x, PHONE_REVEAL_SECONDS)
	tween.tween_property(phone, "modulate:a", 1.0, PHONE_REVEAL_SECONDS)


## Affiche la section choisie dans les 2/3 restants — une seule à la fois,
## jamais superposées : tout enfant précédent est libéré avant d'ajouter le
## nouveau.
func _on_phone_icon_pressed(section_id: String) -> void:
	if not PHONE_SECTIONS.has(section_id):
		return

	for child in _phone_section_host.get_children():
		child.queue_free()

	# has_signal() plutôt qu'un type précis : les sections (sms/mail/galerie/
	# coffre) n'ont pas de classe de base commune (voir PHONE_SECTIONS), et
	# seule MailSection propose un bouton X pour l'instant.
	var section: Node = PHONE_SECTIONS[section_id].instantiate()
	if section.has_signal("close_requested"):
		section.close_requested.connect(_on_phone_section_close_requested)
	# Seul VaultSection émet ceci pour l'instant (pensée d'aide sur mauvais
	# mot de passe) — même raison de passer par has_signal() que ci-dessus.
	if section.has_signal("thought_requested"):
		section.thought_requested.connect(_show_player_thought)
	_phone_section_host.add_child(section)
	_phone_section_host.visible = true


## Le X d'une section (voir MailSection) ramène le téléphone à son écran
## d'accueil — les icônes seules, sans contenu ouvert — comme avant qu'aucune
## icône n'ait encore été pressée.
func _on_phone_section_close_requested() -> void:
	for child in _phone_section_host.get_children():
		child.queue_free()
	_phone_section_host.visible = false
	_alizee_phone.clear_active_icon()
