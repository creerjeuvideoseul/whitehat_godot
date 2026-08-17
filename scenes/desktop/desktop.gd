extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). Owns spawning windows into WindowLayer, the area reserved between
## the header and footer, and wires each window's minimize button to the
## footer's taskbar. The header/footer otherwise manage themselves
## (desktop_header.gd, desktop_footer.gd).

const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const CLUE_BOARD_WINDOW := preload("res://scenes/desktop/windows/clue_board_window.tscn")
const THOUGHT_LOG_WINDOW := preload("res://scenes/desktop/windows/thought_log_window.tscn")
const OSINT_WINDOW := preload("res://scenes/desktop/windows/osint_window.tscn")
const TERMINAL_CONSOLE := preload("res://scenes/ui/terminal_console.tscn")
const PLAYER_THOUGHT := preload("res://scenes/ui/player_thought.tscn")
const ANALYSIS_TRANSITION := preload("res://scenes/ui/analysis_transition.tscn")
const REPORT_GENERATION_SCREEN := preload("res://scenes/ui/report_generation_screen.tscn")
const CLUE_BOARD_TOOLTIP := preload("res://scenes/ui/clue_board_tooltip.tscn")
## Délai entre l'ouverture de "Collecte d'indices" et l'apparition de la bulle
## d'aide "recherche darkweb" (voir _maybe_show_clue_board_tooltip).
const CLUE_BOARD_TOOLTIP_DELAY_SECONDS := 1.5
const HACK_PC_MOTHER_WINDOW := preload("res://scenes/desktop/windows/hack_pc_mother_window.tscn")
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
## De combien la chose révélée (téléphone d'Alizée, fenêtre du PC de la mère)
## doit commencer à apparaître avant la fin réelle de la transition "analyse
## en cours" (voir _play_analysis_transition_and_reveal_phone/
## _play_analysis_transition_and_reveal_hack_pc_mother_window) — partagée par
## les deux, même effet recherché dans les deux cas.
const ANALYSIS_EARLY_REVEAL_SECONDS := 0.7
## Durée/amplitude du glissement de rangement de la fenêtre de chat vers la
## barre des tâches (voir _minimize_window_with_slide), même esprit que
## PHONE_REVEAL_SECONDS/OFFSET mais en sens inverse (vers le bas).
const CHAT_MINIMIZE_SLIDE_SECONDS := 0.65
## Volontairement plus longue que CHAT_MINIMIZE_SLIDE_SECONDS : le fondu ne
## doit pas se terminer pile en même temps que le glissement, sinon la
## fenêtre semble juste "descendre un peu puis disparaître" au lieu de
## continuer visiblement sa course vers la barre des tâches avant de
## s'effacer (retour joueur, voir _minimize_window_with_slide).
const CHAT_MINIMIZE_FADE_SECONDS := 0.9
const CHAT_MINIMIZE_SLIDE_OFFSET := 80.0
## The mission the "Indice" button currently opens. No mission-selection UI
## exists yet, so this is hardcoded for now — same simplification the chat
## contacts already make (see JEAN_REVEAL_DELAY_SECONDS below).
const CURRENT_MISSION_ID := 1
const RELAYGHOST_AVATAR := preload("res://assets/avatar/relayghost_avatar.png")
const RELAYGHOST_DIALOGUE: DialogueResource = preload("res://dialogue/relayghost_intro.dialogue")
## Contenu du bouton "Aide" du footer, rejouable à volonté — voir
## ChatContact.help_dialogue_resource et _on_help_button_pressed.
const RELAYGHOST_HELP_DIALOGUE: DialogueResource = preload("res://dialogue/relayghost_help.dialogue")
const JEAN_AVATAR := preload("res://assets/avatar/portrait_jean.webp")
const JEAN_DIALOGUE: DialogueResource = preload("res://dialogue/jean_intro.dialogue")
## Adresse IP simulée du PC de la mère (voir _build_hack_pc_mother_login_lines) —
## cohérente avec le mail crypté qui déclenche ce piratage (voir mail_section.gd).
const HACK_PC_MOTHER_IP := "180.252.12.44"
## Mot de passe RDP de Christine, trouvable dans sa fiche OSINT (voir
## data/osint_characters.json, champ "Mots de passe") — comparé de façon
## insensible à la casse et au séparateur "_"/espace (voir
## TerminalConsole._normalize_login_password).
const HACK_PC_MOTHER_PASSWORD := "Putriku_tersayang"
## Plus grand que la taille par défaut de TerminalConsole (1100×680, voir
## TerminalConsole.box_size) — seulement pour ce terminal de connexion RDP,
## pas pour les autres usages de la même scène (boot système de l'intro, dump
## de Jean).
const HACK_PC_MOTHER_TERMINAL_SIZE := Vector2(1180.0, 730.0)

## The chat window auto-opens on desktop load for now — there's no "how do
## you open a window" system yet (icons, notifications, ...), so this is
## provisional wiring to keep everything testable end to end.

## Laisse le joueur "seul" sur le bureau un court instant avant que la
## fenêtre de discussion n'apparaisse, plutôt que de la voir surgir
## immédiatement à l'arrivée sur le bureau.
const DESKTOP_ENTRY_DELAY_SECONDS := 3.0

## Musique de fond du bureau (voir MusicPlayer.play_background) : démarrée
## dans _ready() dès que le joueur arrive sur le bureau, que ce soit une
## toute première connexion ou la reprise d'une sauvegarde antérieure à la
## fin de la discussion avec Jean — coupée dans _build_chat_window() dès que
## contact_conversation_finished signale "jean_ranoud". Piste dédiée
## (play_background(), pas play()) : une musique au premier plan (ex. celle
## d'un mail crypté, voir mail_section.gd) la coupe automatiquement sans
## qu'il faille s'en occuper ici.
const DESKTOP_MUSIC := preload("res://assets/audio/chill_background-bathroom-chill-background-music-14977.mp3")
const DESKTOP_MUSIC_FADE_IN_SECONDS := 5.0
const DESKTOP_MUSIC_FADE_OUT_SECONDS := 2.0

## Jean only shows up in the sidebar once RelayGhost's briefing is over, with
## a short pause first so the two don't blur together.
const JEAN_REVEAL_DELAY_SECONDS := 1.0

## Laisse le temps au joueur de "digérer" la fin de la conversation avec Jean
## (dont les 3 lignes System: finales, voir jean_intro.dialogue) avant que le
## terminal système (dump du téléphone) ne s'ouvre par-dessus. Passé de 2 à 4s
## (retour joueur) : 2s ne suffisait pas à lire ces dernières lignes système.
const JEAN_DUMP_TERMINAL_DELAY_SECONDS := 4.0

@onready var _window_layer: Control = %WindowLayer
@onready var _footer: Control = %DesktopFooter
@onready var _header: DesktopHeader = %DesktopHeader
@onready var _phone_section_host: Control = %PhoneSectionHost

## Kept so pressing "Indice" a second time re-shows the same window (and its
## already-unlocked state) instead of rebuilding it from scratch — this
## window closes (×) rather than minimizes (see clue_board_window.gd), no
## taskbar entry to juggle like the other windows below.
var _clue_board_window: ClueBoardWindow = null

## Bulle d'aide "recherche darkweb" (voir ClueBoardTooltip et
## _maybe_show_clue_board_tooltip) — gardée pour ne jamais en superposer une
## seconde tant que le joueur n'a pas fermé celle déjà affichée.
var _clue_board_tooltip: ClueBoardTooltip = null
## Vrai pendant le délai d'apparition de _clue_board_tooltip (voir
## CLUE_BOARD_TOOLTIP_DELAY_SECONDS) — évite qu'un second clic sur "Indice"
## pendant ce délai ne relance une seconde attente en parallèle.
var _clue_board_tooltip_pending: bool = false

## Même principe que _clue_board_window : une seule fenêtre "Analyse
## Rétrospective" réutilisée à chaque clic sur le bouton "Pensées" du footer —
## voir _on_thought_log_button_pressed.
var _thought_log_window: ThoughtLogWindow = null

## Même principe que _clue_board_window : une seule fenêtre OSINT réutilisée
## d'une recherche à l'autre (jamais de doublon, se ferme au lieu de se
## réduire — voir osint_window.gd), son contenu étant entièrement remplacé à
## chaque recherche par OsintWindow.search().
var _osint_window: OsintWindow = null

## Même principe que _clue_board_window/_osint_window : une seule fenêtre
## réutilisée, déclenchée depuis MailSection (voir mail_section.gd,
## hack_pc_mother_requested) tant que le mail crypté de la mère porte ce
## déclencheur dans meta_info.
var _hack_pc_mother_window: HackPcMotherWindow = null
var _hack_pc_mother_window_title: String = ""
## Terminal de connexion RDP (voir _play_hack_pc_mother_login_terminal) —
## réductible comme les fenêtres ci-dessus le temps que le joueur aille
## chercher le mot de passe dans les mails ; se libère de lui-même (queue_free)
## une fois le mot de passe validé, pas besoin de le garder après coup.
var _hack_pc_mother_login_console: TerminalConsole = null
var _hack_pc_mother_login_console_title: String = ""

## Le téléphone d'Alizée reste affiché en permanence une fois révélé — pas de
## fermeture/minimisation prévue, donc une seule instance possible (utile
## surtout pour éviter d'en recréer une seconde au retour d'une sauvegarde).
var _alizee_phone: AlizeePhone = null

## Référence à la fenêtre de discussion RelayGhost/Jean ouverte au tout début
## du bureau — gardée pour pouvoir la ranger (voir _minimize_window_with_slide)
## une fois le téléphone d'Alizée sur le point d'apparaître.
var _chat_window: ChatWindow = null


func _ready() -> void:
	_header.clue_button_pressed.connect(_on_clue_button_pressed)
	_header.osint_search_requested.connect(_on_osint_search_requested)
	_footer.thought_log_button_pressed.connect(_on_thought_log_button_pressed)
	_footer.help_button_pressed.connect(_on_help_button_pressed)
	_header.apply_resumed_clue_state(ClueManager.has_unlocked_mission_solution(CURRENT_MISSION_ID))

	# Reprise d'une sauvegarde postérieure à l'appel de Jean : le téléphone
	# doit déjà être là, sans rejouer son animation d'apparition.
	var jean_done := SaveManager.is_conversation_complete("jean_ranoud")
	if jean_done:
		_reveal_alizee_phone(false)
		# Sans ça, la conversation RelayGhost/Jean n'était accessible que
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

	# Toute arrivée sur le bureau avant la fin de la discussion avec Jean —
	# première connexion ou reprise d'une sauvegarde antérieure (voir jean_done
	# ci-dessus) — relance la musique de fond depuis le début plutôt que de la
	# limiter à la toute première connexion.
	MusicPlayer.play_background(DESKTOP_MUSIC, DESKTOP_MUSIC_FADE_IN_SECONDS)

	# L'ouverture automatique après un délai ne doit surprendre que tant qu'il
	# reste quelque chose à découvrir dans le chat (première arrivée après
	# l'intro/login, ou reprise entre la fin de RelayGhost et celle de Jean) —
	# pas une reprise après coup, où tout a déjà été lu et où seul le
	# téléphone d'Alizée reste à l'écran. Pas de is_conversation_complete("relayghost")
	# ici : ça stranderait le joueur qui reprend juste après RelayGhost, sans
	# autre moyen de rouvrir le chat pour parler à Jean (pas d'icône/taskbar
	# pour ça pour l'instant).
	# Immédiat, sans attendre le délai d'ouverture du chat ci-dessous —
	# seulement le tout premier contact, pas la reprise "entre RelayGhost et
	# Jean" couverte par cette même branche (voir commentaire ci-dessus), où
	# RelayGhost a déjà été rencontré lors d'une session précédente.
	if not SaveManager.is_conversation_complete("relayghost"):
		_show_player_thought(tr("THOUGHT_RELAYGHOST_CONTACT"), "THOUGHT_RELAYGHOST_CONTACT")

	await get_tree().create_timer(DESKTOP_ENTRY_DELAY_SECONDS).timeout
	_chat_window = _build_chat_window()
	_open_window(_chat_window)


## Petit encart "pensée du joueur" en bas de l'écran (voir player_thought.gd)
## — se montre et se referme tout seul, rien à garder côté appelant. Journalise
## aussi la pensée dans SaveManager (voir ThoughtLogWindow) : `translation_key`
## vide si l'appelant n'a pas de clé ui.csv pour ce texte (ex. pensées
## déclenchées depuis le mail, déjà résolues par langue dans le JSON de
## données — voir mail_section.gd).
func _show_player_thought(text: String, translation_key: String = "") -> void:
	var thought: PlayerThought = PLAYER_THOUGHT.instantiate()
	thought.text = text
	_window_layer.add_child(thought)
	SaveManager.record_thought(text, translation_key)


func _build_chat_window() -> ChatWindow:
	var window: ChatWindow = CHAT_WINDOW.instantiate()
	window.contacts = [_build_relayghost_contact()]
	# Si la conversation avec RelayGhost est déjà terminée (reprise d'une
	# sauvegarde), le signal contact_conversation_finished ne se redéclenchera
	# jamais — _replay_saved_log() ne le réémet pas. Jean doit donc déjà être
	# dans la liste initiale plutôt que d'attendre ce signal.
	if SaveManager.is_conversation_complete("relayghost"):
		window.contacts.append(_build_jean_contact())
	window.contact_conversation_finished.connect(func(contact_id: String) -> void:
		if contact_id == "relayghost":
			await get_tree().create_timer(JEAN_REVEAL_DELAY_SECONDS).timeout
			window.add_contact(_build_jean_contact())
		elif contact_id == "jean_ranoud":
			MusicPlayer.stop_background(DESKTOP_MUSIC_FADE_OUT_SECONDS)
			await get_tree().create_timer(JEAN_DUMP_TERMINAL_DELAY_SECONDS).timeout
			_play_jean_dump_terminal()
	)
	return window


func _build_relayghost_contact() -> ChatContact:
	var contact := ChatContact.new()
	contact.contact_id = "relayghost"
	contact.contact_name = "RelayGhost"
	contact.avatar = RELAYGHOST_AVATAR
	contact.dialogue_resource = RELAYGHOST_DIALOGUE
	contact.help_dialogue_resource = RELAYGHOST_HELP_DIALOGUE
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

	# Redescend juste avant l'apparition du téléphone (voir
	# _play_analysis_transition_and_reveal_phone) — couvre tout le temps où le
	# terminal ET l'écran "chargement des données" sont à l'écran.
	_header.set_system_load_spike(true)

	var console: TerminalConsole = TERMINAL_CONSOLE.instantiate()
	console.lines = _build_jean_dump_lines()
	console.typing_sound = SfxPlayer.TERMINAL_TYPING_SFX
	console.fade_out_on_close = true
	console.closed.connect(_on_jean_dump_terminal_closed)
	add_child(console)


## Une fois le terminal fermé : la fenêtre de chat (devenue accessoire, la
## conversation avec Jean est terminée) se range dans la barre des tâches,
## puis une transition "analyse en cours" (voir AnalysisTransition — barre de
## progression façon scp/rsync, dans la continuité visuelle du terminal qui
## vient de tourner) couvre le bureau central le temps de la bascule — évite
## le "cut" brutal terminal → téléphone. Remplace l'ancien fondu au noir
## (SceneTransition, toujours utilisé ailleurs pour les changements de
## scène) : si cet effet ne convenait pas, il suffit de remettre les deux
## lignes SceneTransition.fade_out/fade_in ici à la place de
## _play_analysis_transition_and_reveal_phone(). Le téléphone d'Alizée,
## point d'entrée de l'enquête, apparaît ensuite avec sa propre animation.
func _on_jean_dump_terminal_closed() -> void:
	# .visible : si le joueur avait déjà réduit la fenêtre de lui-même avant
	# la fin de la discussion, un second rangement créerait un doublon dans
	# la barre des tâches (voir DesktopFooter.add_minimized_window, qui ne
	# déduplique pas par titre comme le font Indice/OSINT).
	if is_instance_valid(_chat_window) and _chat_window.visible:
		await _minimize_window_with_slide(_chat_window, tr("CHAT_WINDOW_TITLE"))

	await _play_analysis_transition_and_reveal_phone()


## N'affecte que WindowLayer (le bureau central) — le header/footer restent
## visibles, contrairement à SceneTransition qui couvre tout l'écran.
##
## Le téléphone commence à apparaître PHONE_EARLY_REVEAL_SECONDS avant la fin
## réelle de la transition (pas d'await sur transition.finished) : il émerge
## de l'écran d'analyse plutôt que d'attendre qu'il ait entièrement disparu.
## Repositionné juste avant la transition dans WindowLayer (move_child) pour
## rester masqué tant qu'elle est encore opaque — elle continue de tourner/
## s'effacer en arrière-plan et se libère toute seule (voir
## AnalysisTransition._ready(), fondu de sortie final).
func _play_analysis_transition_and_reveal_phone() -> void:
	var transition: AnalysisTransition = ANALYSIS_TRANSITION.instantiate()
	_window_layer.add_child(transition)

	var wait_seconds := maxf(0.0, AnalysisTransition.TOTAL_SECONDS - ANALYSIS_EARLY_REVEAL_SECONDS)
	await get_tree().create_timer(wait_seconds).timeout

	_header.set_system_load_spike(false)
	_reveal_alizee_phone(true)
	if is_instance_valid(_alizee_phone) and is_instance_valid(transition):
		_window_layer.move_child(_alizee_phone, transition.get_index())


## Glissement + fondu vers le bas (même esprit que _animate_reveal_slide,
## sens inverse) avant de ranger réellement la fenêtre — pour un rangement
## visible plutôt que la disparition instantanée du bouton "réduire".
func _minimize_window_with_slide(window: Control, window_title: String) -> void:
	var origin_y := window.position.y

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(window, "position:y", origin_y + CHAT_MINIMIZE_SLIDE_OFFSET, CHAT_MINIMIZE_SLIDE_SECONDS)
	tween.tween_property(window, "modulate:a", 0.0, CHAT_MINIMIZE_FADE_SECONDS)
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
## BBCode hex ("#rrggbb") d'une couleur Palette — factorisé pour ne pas
## recalculer le même Palette.X.to_html(false) dans chaque script de terminal
## (dump de Jean, connexion RDP du PC de la mère) : un seul endroit à changer
## si le format de couleur BBCode devait un jour évoluer.
func _terminal_color_hex(color: Color) -> String:
	return "#%s" % color.to_html(false)


func _build_jean_dump_lines() -> Array[TerminalLine]:
	var prompt := _terminal_color_hex(Palette.BORDER_ACCENT)
	var normal := _terminal_color_hex(Palette.TEXT_NORMAL)
	var muted := _terminal_color_hex(Palette.CONSOLE_TEXT)
	var accent := _terminal_color_hex(Palette.TEXT_ACCENT)

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


## Une fenêtre réutilisée (show() sans repasser par add_child) garde le rang
## qu'elle avait dans _window_layer au moment de sa création — jamais mis à
## jour depuis, contrairement à sa visibilité. Ça la laissait derrière le
## téléphone d'Alizée (ajouté après elle) une fois rouverte (retour joueur :
## Indice/OSINT passaient derrière). L'ordre des enfants d'un Control pilote
## l'empilement visuel : le dernier enfant se dessine au premier plan.
func _bring_window_to_front(window: Control) -> void:
	_window_layer.move_child(window, _window_layer.get_child_count() - 1)


func _on_window_minimize_requested(window: Control, window_title: String) -> void:
	if window == _hack_pc_mother_window:
		_hack_pc_mother_window_title = window_title
	elif window == _hack_pc_mother_login_console:
		_hack_pc_mother_login_console_title = window_title
	_footer.add_minimized_window(window_title, func() -> void:
		window.show()
		_bring_window_to_front(window)
	)


## "Indice" always reopens the same board so its layout/unlocked state isn't
## rebuilt from scratch every click — only the first press instantiates it.
## Pas de passage par _open_window()/la barre des tâches : cette fenêtre se
## ferme (×) plutôt que se réduit, le bouton "Indice" du header (toujours
## visible) suffit à la retrouver — voir clue_board_window.gd.
func _on_clue_button_pressed() -> void:
	if is_instance_valid(_clue_board_window):
		_clue_board_window.show()
		_bring_window_to_front(_clue_board_window)
	else:
		_clue_board_window = CLUE_BOARD_WINDOW.instantiate()
		_clue_board_window.mission_id = CURRENT_MISSION_ID
		_clue_board_window.generate_report_requested.connect(_on_generate_report_requested)
		_clue_board_window.thought_requested.connect(_show_player_thought)
		_window_layer.add_child(_clue_board_window)

	_maybe_show_clue_board_tooltip()


## Bulle d'aide "recherche darkweb" (voir ClueBoardTooltip) : montrée une
## seule fois par partie, à la première ouverture de "Collecte d'indices" qui
## coïncide avec au moins un indice déjà débloqué pour la mission en cours —
## pas forcément le tout premier clic (voir SaveManager.
## has_seen_clue_board_tooltip()) : un joueur qui ouvre la fenêtre avant même
## d'avoir rencontré Jean n'a encore rien à chercher, la bulle attend donc la
## prochaine ouverture où c'est le cas plutôt que de ne plus jamais
## apparaître. Apparaît CLUE_BOARD_TOOLTIP_DELAY_SECONDS après l'ouverture,
## le temps que le joueur ait fini de regarder le tableau lui-même plutôt que
## de la voir surgir en même temps.
## _clue_board_tooltip_pending évite d'en déclencher une seconde si le joueur
## reclique "Indice" pendant le délai d'attente ; is_instance_valid(_clue_board_tooltip)
## fait de même une fois la bulle réellement affichée mais pas encore fermée.
func _maybe_show_clue_board_tooltip() -> void:
	if is_instance_valid(_clue_board_tooltip) or _clue_board_tooltip_pending:
		return
	if SaveManager.has_seen_clue_board_tooltip():
		return
	if not ClueManager.has_mission_started(CURRENT_MISSION_ID):
		return

	_clue_board_tooltip_pending = true
	await get_tree().create_timer(CLUE_BOARD_TOOLTIP_DELAY_SECONDS).timeout
	_clue_board_tooltip_pending = false

	# Le joueur a pu refermer la fenêtre Collecte d'indices pendant le délai —
	# pas de raison de faire surgir la bulle sur un bureau où elle ne pointe
	# plus vers rien d'ouvert.
	if not is_instance_valid(_clue_board_window) or not _clue_board_window.visible:
		return

	var field_rect := _header.get_search_field_global_rect()
	_clue_board_tooltip = CLUE_BOARD_TOOLTIP.instantiate()
	# Ajoutée directement sur la racine du bureau (pas _window_layer) : la
	# flèche doit toucher un champ du header, donc passer devant lui, or
	# DesktopHeader est ajouté après WindowLayer dans desktop.tscn (dessiné
	# par-dessus). Devenir le tout dernier enfant de Desktop suffit à passer
	# devant header ET footer, sans toucher à l'empilement des autres fenêtres.
	add_child(_clue_board_tooltip)
	_clue_board_tooltip.set_text("CLUEBOARD_TOOLTIP_DARKWEB_HINT")
	_clue_board_tooltip.point_at(Vector2(field_rect.position.x + field_rect.size.x * 0.5, field_rect.position.y + field_rect.size.y))
	_clue_board_tooltip.closed.connect(func() -> void:
		SaveManager.mark_clue_board_tooltip_seen()
		_clue_board_tooltip.queue_free()
	)


## "Pensées" du footer, même schéma que "Indice" ci-dessus : une seule
## instance réutilisée, jamais fermée/détruite. refresh() est appelé à chaque
## clic (pas seulement à la création) pour refléter les pensées ajoutées
## depuis la dernière ouverture — contrairement à ClueBoardWindow, cette
## fenêtre n'écoute aucun signal pour se mettre à jour toute seule pendant
## qu'elle reste ouverte, ce n'est pas nécessaire ici.
func _on_thought_log_button_pressed() -> void:
	if not is_instance_valid(_thought_log_window):
		_thought_log_window = THOUGHT_LOG_WINDOW.instantiate()
		_window_layer.add_child(_thought_log_window)
	_thought_log_window.refresh()
	_thought_log_window.show()
	_bring_window_to_front(_thought_log_window)


## "Aide" du footer : rouvre (ou remonte) la fenêtre de chat déjà existante à
## ce stade (voir set_help_button_visible, caché jusqu'à l'apparition du
## téléphone d'Alizée) sur l'onglet RelayGhost, puis rejoue le titre "help" de
## son dialogue — voir ChatWindow.trigger_help/ConversationView.trigger_help.
func _on_help_button_pressed() -> void:
	if not is_instance_valid(_chat_window):
		return
	if not _chat_window.visible:
		_chat_window.show()
		_footer.remove_minimized_window(tr("CHAT_WINDOW_TITLE"))
	_bring_window_to_front(_chat_window)
	_chat_window.trigger_help("relayghost")


## N'arrive qu'après confirmation du joueur (voir ClueBoardWindow.
## ReportConfirmDialog, "pas de retour en arrière possible") : un vrai
## changement de scène plutôt qu'une fenêtre par-dessus le bureau, puisque
## ClueBoardWindow ne rouvrira plus derrière — même fondu (SceneTransition)
## que les autres changements de scène du jeu (voir introduction.gd). Contenu
## du rapport lui-même (report_generation_screen.gd) à venir dans une
## prochaine passe ; pour l'instant l'écran n'a que son propre header/footer.
func _on_generate_report_requested() -> void:
	await SceneTransition.fade_out()
	get_tree().change_scene_to_packed(REPORT_GENERATION_SCREEN)
	SceneTransition.fade_in()


## Même principe que _on_clue_button_pressed/_on_osint_search_requested :
## une seule instance réutilisée, jamais de doublon dans la taskbar. La toute
## première fois, la fenêtre n'apparaît qu'après le terminal de connexion RDP
## (voir _play_hack_pc_mother_login_terminal) — pas de persistance d'une
## sauvegarde à l'autre, comme _hack_pc_mother_window lui-même.
func _on_hack_pc_mother_requested() -> void:
	if is_instance_valid(_hack_pc_mother_window):
		_footer.remove_minimized_window(_hack_pc_mother_window_title)
		_hack_pc_mother_window.show()
		_bring_window_to_front(_hack_pc_mother_window)
		return

	# Le terminal de connexion est réductible (voir _play_hack_pc_mother_login_terminal) :
	# sans ce garde-fou, recliquer PIRATER LE PC pendant qu'il tourne déjà
	# (réduit ou non) en relancerait un second en plus du premier.
	if is_instance_valid(_hack_pc_mother_login_console):
		_footer.remove_minimized_window(_hack_pc_mother_login_console_title)
		_hack_pc_mother_login_console.show()
		return

	_play_hack_pc_mother_login_terminal()


## Terminal "système" (voir TerminalConsole) qui simule un scan réseau puis
## une connexion RDP jusqu'à une demande de mot de passe — le joueur a autant
## de tentatives que voulu (mot de passe trouvable dans la fiche OSINT de
## Christine). Réductible (window_title) : rien n'empêche d'aller relire le
## mail de la mère pendant que ce terminal attend une saisie. Se ferme tout
## seul dès que le mot de passe est correct (voir TerminalConsole.login_prompt_text),
## ce qui déclenche closed ci-dessous.
func _play_hack_pc_mother_login_terminal() -> void:
	var danger := _terminal_color_hex(Palette.TEXT_DANGER)

	var console: TerminalConsole = TERMINAL_CONSOLE.instantiate()
	console.box_size = HACK_PC_MOTHER_TERMINAL_SIZE
	console.lines = _build_hack_pc_mother_login_lines()
	console.typing_sound = SfxPlayer.TERMINAL_TYPING_SFX
	console.login_prompt_text = "Password for Christine@%s:" % HACK_PC_MOTHER_IP
	console.login_expected_password = HACK_PC_MOTHER_PASSWORD
	console.login_wrong_message = "[color=%s]%s[/color]" % [danger, tr("TERMINAL_WRONG_PASSWORD")]
	console.window_title = tr("TERMINAL_WINDOW_TITLE")
	console.closed.connect(_on_hack_pc_mother_login_succeeded)
	# Pas au tout début du terminal (le scan réseau/la connexion tournent encore
	# à ce moment-là) : seulement une fois qu'il en arrive vraiment à demander
	# le mot de passe — voir TerminalConsole.login_gate_started.
	console.login_gate_started.connect(func() -> void:
		_show_player_thought(tr("THOUGHT_HACK_PC_MOTHER_PASSWORD"), "THOUGHT_HACK_PC_MOTHER_PASSWORD")
	)
	_hack_pc_mother_login_console = console
	_open_window(console)


## Le mot de passe correct ferme le terminal (voir closed ci-dessus) puis
## enchaîne sur la même transition "analyse en cours" que celle utilisée
## entre la fin de l'appel de Jean et l'apparition du téléphone d'Alizée
## (voir _play_analysis_transition_and_reveal_phone) — même bascule, pas de
## raison d'en inventer une autre pour ce second "dump de données".
func _on_hack_pc_mother_login_succeeded() -> void:
	_hack_pc_mother_login_console = null
	await _play_analysis_transition_and_reveal_hack_pc_mother_window()


## Même recette que _play_analysis_transition_and_reveal_phone (transition,
## puis la fenêtre émerge à travers son fondu de sortie plutôt que d'attendre
## qu'elle ait fini) — dupliquée plutôt que factorisée : les deux revealed
## (Control plein écran vs fenêtre réductible) et leurs effets d'entrée
## (glissement latéral vs glissement + SFX déjà géré par _animate_reveal_slide)
## ne partagent pas assez pour valoir une abstraction commune à ce stade.
func _play_analysis_transition_and_reveal_hack_pc_mother_window() -> void:
	var transition: AnalysisTransition = ANALYSIS_TRANSITION.instantiate()
	_window_layer.add_child(transition)

	var wait_seconds := maxf(0.0, AnalysisTransition.TOTAL_SECONDS - ANALYSIS_EARLY_REVEAL_SECONDS)
	await get_tree().create_timer(wait_seconds).timeout

	_hack_pc_mother_window = HACK_PC_MOTHER_WINDOW.instantiate()
	_open_window(_hack_pc_mother_window)
	SfxPlayer.play(SfxPlayer.MAJOR_REVEAL_SFX)
	_animate_reveal_slide(_hack_pc_mother_window)
	if is_instance_valid(_hack_pc_mother_window) and is_instance_valid(transition):
		_window_layer.move_child(_hack_pc_mother_window, transition.get_index())


## Script du scan réseau + de la connexion RDP simulés avant la demande de mot
## de passe (voir _play_hack_pc_mother_login_terminal) — jargon technique brut
## non traduit quelle que soit la langue, même choix que _build_jean_dump_lines
## (un vrai terminal ne se traduit pas), sauf la toute dernière ligne qui
## passe par ui.csv (seule phrase en langage naturel du script). Les crochets
## littéraux de la sortie des outils ([+], [INFO], [Christine]...) sont
## échappés en [lb]/[rb] : ce ne sont pas des balises BBCode, juste du texte
## de commande.
func _build_hack_pc_mother_login_lines() -> Array[TerminalLine]:
	var prompt := _terminal_color_hex(Palette.BORDER_ACCENT)
	var normal := _terminal_color_hex(Palette.TEXT_NORMAL)
	var muted := _terminal_color_hex(Palette.CONSOLE_TEXT)
	var accent := _terminal_color_hex(Palette.TEXT_ACCENT)
	var ip := HACK_PC_MOTHER_IP

	var lines: Array[TerminalLine] = []

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]ping %s[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s]PING %s (%s) 56(84) bytes of data.[/color]" % [muted, ip, ip]))
	lines.append(TerminalLine.text_line("[color=%s]64 bytes from %s: icmp_seq=1 ttl=128 time=142 ms[/color]" % [muted, ip]))
	lines.append(TerminalLine.text_line("[color=%s]64 bytes from %s: icmp_seq=2 ttl=128 time=139 ms[/color]" % [muted, ip]))
	lines.append(TerminalLine.text_line("[color=%s]--- %s ping statistics ---[/color]" % [muted, ip]))
	lines.append(TerminalLine.text_line("[color=%s]2 packets transmitted, 2 received, 0%% packet loss, time 1001ms[/color]" % muted))

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]nmap -p 135,139,445,3389 %s[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s]Starting Nmap 7.94 ( https://nmap.org ) at 2030-01-30 09:15 CET[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]Nmap scan report for %s[/color]" % [muted, ip]))
	lines.append(TerminalLine.text_line("[color=%s]PORT     STATE SERVICE[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]135/tcp  open  msrpc[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]139/tcp  open  netbios-ssn[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]445/tcp  open  microsoft-ds[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]3389/tcp open  ms-wbt-server[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]Nmap done: 1 IP address (1 host up) scanned in 1.42 seconds[/color]" % muted))

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]nmap -sV --script rdp-enum-encryption,smb-os-discovery -p 445,3389 %s[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s]PORT     STATE SERVICE       VERSION[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]445/tcp  open  microsoft-ds  Windows 10 Home 19045[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]| smb-os-discovery:[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]|   OS: Windows 10 Home (Windows 10 Home 6.3)[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]|_  Computer name: [color=%s]DESKTOP-CRANOUD[/color][/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s]3389/tcp open  ms-wbt-server Microsoft Terminal Services[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]|_rdp-enum-encryption: CredSSP (NLA) supported, RDP encryption supported[/color]" % muted))

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]smbclient -L //%s -N[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s][color=%s]Anonymous login successful[/color][/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s]Sharename       Type      Comment[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]---------       ----      -------[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]ADMIN$          Disk      Remote Admin[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]C$              Disk      Default share[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]Users           Disk      Public Directory[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]IPC$            IPC       Remote IPC[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]Reconnecting with SMB1 for workgroup listing.[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]Server           Comment[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]---------        -------[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s]DESKTOP-CRANOUD  Workgroup: WORKGROUP[/color]" % muted))

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]enum4linux -U %s | grep \"user:\"[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s][lb]+[rb] User count: 2[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s][lb]+[rb] user:[lb][color=%s]Christine[/color][rb] rid:[lb]0x3e8[rb][/color]" % [muted, accent]))
	lines.append(TerminalLine.text_line("[color=%s][lb]+[rb] user:[lb]DefaultAccount[rb] rid:[lb]0x1f7[rb][/color]" % muted))

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]nc -zv %s 3389[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s]Connection to %s 3389 port [lb]tcp/ms-wbt-server[rb] [color=%s]succeeded![/color][/color]" % [muted, ip, accent]))

	lines.append(TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]xfreerdp /v:%s /u:Christine /cert:ignore[/color]" % [prompt, normal, ip], true))
	lines.append(TerminalLine.text_line("[color=%s][lb]09:18:02:112[rb] [lb]INFO[rb][lb]com.freerdp.core[rb] - Connecting to host %s:3389[/color]" % [muted, ip]))
	lines.append(TerminalLine.text_line("[color=%s][lb]09:18:02:450[rb] [lb]INFO[rb][lb]com.freerdp.tls[rb] - TLS connection established with CredSSP[/color]" % muted))
	lines.append(TerminalLine.text_line("[color=%s][lb]09:18:02:810[rb] [lb]INFO[rb][lb]com.freerdp.core[rb] - Authentication required for user: [color=%s]Christine[/color][/color]" % [muted, accent]))

	# Seule phrase en langage naturel de tout le script (voir doc de fonction) :
	# passe par ui.csv, bien visible en vert juste avant la demande de mot de
	# passe (voir TerminalConsole.login_prompt_text).
	lines.append(TerminalLine.text_line("[color=%s]%s[/color]" % [accent, tr("TERMINAL_LOGIN_ACCESS_GRANTED")]))

	return lines


## Une recherche OSINT réutilise toujours la même fenêtre (jamais de
## doublon) : elle se rouvre si elle était fermée, et son contenu précédent
## est systématiquement remplacé par le nouveau résultat.
func _on_osint_search_requested(query: String) -> void:
	if is_instance_valid(_osint_window):
		_osint_window.show()
		_bring_window_to_front(_osint_window)
	else:
		_osint_window = OSINT_WINDOW.instantiate()
		_window_layer.add_child(_osint_window)

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
	# Le bouton "Aide" n'a de sens qu'une fois l'enquête vraiment commencée :
	# caché jusqu'à ce que le téléphone d'Alizée apparaisse (après Jean, après
	# le terminal de dump) — pas dès la fin de RelayGhost, voir
	# set_help_button_visible. Couvre aussi bien l'apparition animée en cours
	# de session que la reprise d'une sauvegarde postérieure (animate=false).
	_footer.set_help_button_visible(true)

	if animate:
		SfxPlayer.play(SfxPlayer.ALIZEE_PHONE_REVEAL_SFX)
		_animate_reveal_slide(_alizee_phone)


## Glissement + fondu depuis la gauche, dans le même esprit que le shake de
## ChatWindow (tween direct sur position/modulate, sans toucher aux ancres) —
## partagé par l'apparition du téléphone d'Alizée et celle de la fenêtre
## "Piratage — PC de la mère" une fois le mot de passe RDP validé (voir
## _on_hack_pc_mother_login_succeeded).
func _animate_reveal_slide(control: Control) -> void:
	await get_tree().process_frame
	var target_x := control.position.x
	control.position.x = target_x - PHONE_REVEAL_SLIDE_OFFSET
	control.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "position:x", target_x, PHONE_REVEAL_SECONDS)
	tween.tween_property(control, "modulate:a", 1.0, PHONE_REVEAL_SECONDS)


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
	# Seul MailSection émet ceci pour l'instant (bouton "important" révélé par
	# meta_info.Hack_PC_Mother) — même raison de passer par has_signal() que
	# ci-dessus.
	if section.has_signal("hack_pc_mother_requested"):
		section.hack_pc_mother_requested.connect(_on_hack_pc_mother_requested)
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
