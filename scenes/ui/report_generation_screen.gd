extends Control
## Écran "rapport de mission" : même chrome tête/pied (header/footer, voir
## desktop.tscn) que le bureau — atteint en remplaçant la scène desktop une
## fois la confirmation validée (voir clue_board_window.gd::ReportConfirmDialog
## et desktop.gd::_on_generate_report_requested), sans retour en arrière
## possible.
##
## Contenu du rapport de la mission 1 (fenêtre bleue centrale, voir
## ReportWindow dans la scène) : récit + deux questions Oui/Non (transmettre à
## Jean Ranoud, puis — si l'indice MERE_CLUE_ID a été trouvé pendant l'enquête —
## transmettre la vérité sur Christine à Alizée). "Valider le rapport" ne
## devient bleu/cliquable qu'une fois toutes les questions affichées
## répondues, même recette que GÉNÉRER LE RAPPORT (voir clue_board_window.gd).
## La validation verrouille les réponses, les persiste (StoryVars, voir
## _on_validate_pressed), sauvegarde, puis enchaîne sur une fenêtre système
## simulant l'envoi du rapport (voir _play_report_terminal) et se conclut sur
## RelayGhost (voir _open_relayghost_report_chat) — fin de la mission 1, mais
## tout l'état du joueur (indices, StoryVars, sauvegarde) reste accessible
## pour de futures conséquences. Le score éthique/popularité agrégé (voir la
## bible de design) reste une couche à construire plus tard par-dessus ces
## StoryVars bruts.

const THOUGHT_LOG_WINDOW := preload("res://scenes/desktop/windows/thought_log_window.tscn")
const TERMINAL_CONSOLE := preload("res://scenes/ui/terminal_console.tscn")
const CHAT_WINDOW := preload("res://scenes/desktop/windows/chat_window.tscn")
const RELAYGHOST_AVATAR := preload("res://assets/avatar/relayghost_avatar.png")
## Dialogue joué après l'envoi du rapport (voir _open_relayghost_report_chat)
## — contact_id distinct de "relayghost" (déjà marqué terminé par l'intro,
## voir SaveManager.is_conversation_complete) pour que ce nouveau chapitre
## compte comme une conversation à part.
const RELAYGHOST_REPORT_DIALOGUE: DialogueResource = preload("res://dialogue/relayghost_report_m1.dialogue")
## Joué une fois à l'ouverture de cet écran (voir _ready) — appui dramatique
## sur l'arrivée du rapport final, seul appelant donc pas centralisé dans
## SfxPlayer (même logique que BOOT_SYSTEM_SFX dans introduction.gd).
const REPORT_OPEN_SFX := preload("res://assets/audio/sound/soundreality-boom-128320.mp3")
## Plus long que le défaut (voir TerminalConsole.close_fade_seconds) : un
## fondu plus posé avant l'arrivée de RelayGhost, pas juste un cut technique.
const REPORT_TERMINAL_CLOSE_FADE_SECONDS := 1.0
## Même piste et mêmes paramètres de fondu que la toute première fenêtre
## système du jeu (voir introduction.gd::MONOLOGUE_MUSIC/MUSIC_FADE_SECONDS,
## joué juste avant le boot terminal) — repris ici tel quel, à la demande du
## joueur. Fondu d'entrée dans _play_report_terminal, de sortie dans
## _open_relayghost_report_chat (voir REPORT_TERMINAL_CLOSE_FADE_SECONDS
## ci-dessus pour le fondu visuel du terminal, distinct de celui-ci).
const REPORT_TERMINAL_MUSIC := preload("res://assets/audio/soundreality-cinematic-tension-2-504666.mp3")
const REPORT_TERMINAL_MUSIC_FADE_SECONDS := 1.0
## Indice débloqué en piratant le PC de Christine Ranoud (voir
## hack_pc_mother_window.gd) — sa présence conditionne l'apparition du second
## volet du rapport (informer Alizée de la vraie raison de l'absence de sa mère).
const MERE_CLUE_ID := "M1_SOLUTION_MERE"
## Même recette que desktop_header.gd::_start_clue_button_blink.
const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4

@onready var _header: DesktopHeader = %DesktopHeader
@onready var _footer: Control = %DesktopFooter
@onready var _scroll: ScrollContainer = %Scroll
@onready var _intro_text: RichTextLabel = %IntroText
@onready var _jean_question_label: RichTextLabel = %JeanQuestionLabel
@onready var _jean_yes_button: Button = %JeanYesButton
@onready var _jean_no_button: Button = %JeanNoButton
@onready var _jean_explanation_label: RichTextLabel = %JeanExplanationText
@onready var _mere_intro_text: RichTextLabel = %MereIntroText
@onready var _mere_block: VBoxContainer = %MereBlock
@onready var _mere_text: RichTextLabel = %MereText
@onready var _mere_else_text: RichTextLabel = %MereElseText
@onready var _alizee_question_label: RichTextLabel = %AlizeeQuestionLabel
@onready var _alizee_yes_button: Button = %AlizeeYesButton
@onready var _alizee_no_button: Button = %AlizeeNoButton
@onready var _validate_button: Button = %ValidateButton

## true/false une fois répondu, null tant que le joueur n'a pas encore choisi —
## voir _update_validate_button.
var _jean_answer = null
var _alizee_answer = null

var _thought_log_window: ThoughtLogWindow
var _validate_blink_tween: Tween


func _ready() -> void:
	SfxPlayer.play(REPORT_OPEN_SFX)

	# Ces deux actions du header n'ont plus de sens une fois la mission conclue
	# (voir set_investigation_controls_visible) — le bureau normal, qui
	# instancie son propre header séparé, n'est pas affecté.
	_header.set_investigation_controls_visible(false)
	_footer.thought_log_button_pressed.connect(_on_thought_log_button_pressed)

	# RichTextLabel (pas Label) pour ces quatre-là : sélection/copie du texte
	# demandée par le joueur, même recette que mail_section.gd::_build_body_label.
	# RichTextLabel ne s'auto-traduit pas comme Label, d'où l'assignation ici
	# plutôt que "text = clé" dans la scène (voir credits.tscn/login.tscn pour
	# le même choix ailleurs dans le projet).
	# Les textes du rapport utilisent le pseudo-HTML <color=indice>/<color=important>
	# (voir rich_text_markup.gd) : conversion en BBCode natif nécessaire avant
	# affichage, sinon le RichTextLabel affiche les balises telles quelles.
	_intro_text.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_INTRO_TEXT"))
	_jean_question_label.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_JEAN_QUESTION"))
	# Toujours affiché sous le trait, contrairement à MereText/AlizeeQuestionLabel
	# ci-dessous qui restent conditionnés au hack du PC de Christine.
	_mere_intro_text.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_MERE_INTRO_TEXT"))
	_mere_text.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_MERE_TEXT"))
	_alizee_question_label.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_ALIZEE_QUESTION"))
	_mere_else_text.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_MERE_ELSE_TEXT"))

	# IF le hack a été fait : questionnaire complet (MereBlock) ; ELSE : simple
	# constat qu'aucune information supplémentaire n'a été obtenue.
	var mere_unlocked := ClueManager.is_unlocked(MERE_CLUE_ID)
	_mere_block.visible = mere_unlocked
	_mere_else_text.visible = not mere_unlocked

	_apply_blue_scrollbar()

	_style_choice_button(_jean_yes_button, Palette.TEXT_NORMAL)
	_style_choice_button(_jean_no_button, Palette.TEXT_NORMAL)
	_style_choice_button(_alizee_yes_button, Palette.TEXT_NORMAL)
	_style_choice_button(_alizee_no_button, Palette.TEXT_NORMAL)

	_jean_yes_button.pressed.connect(_on_jean_answer.bind(true))
	_jean_no_button.pressed.connect(_on_jean_answer.bind(false))
	_alizee_yes_button.pressed.connect(_on_alizee_answer.bind(true))
	_alizee_no_button.pressed.connect(_on_alizee_answer.bind(false))
	_validate_button.pressed.connect(_on_validate_pressed)


func _on_jean_answer(is_yes: bool) -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_jean_answer = is_yes
	_style_choice_button(_jean_yes_button, Palette.TEXT_ACCENT if is_yes else Palette.TEXT_DANGER)
	_style_choice_button(_jean_no_button, Palette.TEXT_DANGER if is_yes else Palette.TEXT_ACCENT)
	# N'apparaît qu'une fois choisi (voir doc de classe) : caché par défaut dans
	# la scène, seul le texte correspondant au choix effectivement fait a un
	# sens à montrer.
	_jean_explanation_label.text = RichTextMarkup.html_to_bbcode(tr("REPORT_M1_JEAN_EXPLANATION_YES" if is_yes else "REPORT_M1_JEAN_EXPLANATION_NO"))
	_jean_explanation_label.visible = true
	_update_validate_button()


func _on_alizee_answer(is_yes: bool) -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_alizee_answer = is_yes
	_style_choice_button(_alizee_yes_button, Palette.TEXT_ACCENT if is_yes else Palette.TEXT_DANGER)
	_style_choice_button(_alizee_no_button, Palette.TEXT_DANGER if is_yes else Palette.TEXT_ACCENT)
	_update_validate_button()


## Cliquable (bleu/ImportantButton, clignotant) seulement une fois toutes les
## questions affichées répondues — le volet Alizée ne compte que s'il est
## visible (voir _mere_block.visible, fixé une fois pour toutes dans _ready).
func _update_validate_button() -> void:
	var mere_required := _mere_block.visible
	var is_ready: bool = _jean_answer != null and (not mere_required or _alizee_answer != null)
	_validate_button.disabled = not is_ready
	_validate_button.theme_type_variation = &"ImportantButton" if is_ready else &"PrimaryButton"
	if is_ready:
		_start_validate_blink()
	else:
		_stop_validate_blink()


## Verrouille les réponses (pas de retour en arrière, comme le reste de cette
## étape), persiste les choix (StoryVars, même bac à variables narratives que
## les fichiers .dialogue — voir story_vars.gd), sauvegarde, puis enchaîne sur
## la fenêtre système d'envoi du rapport.
func _on_validate_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_stop_validate_blink()
	_validate_button.disabled = true
	_jean_yes_button.disabled = true
	_jean_no_button.disabled = true
	_alizee_yes_button.disabled = true
	_alizee_no_button.disabled = true

	StoryVars.m1_report_jean_transmit = _jean_answer
	# Ne compte que si le volet était affiché (voir _mere_block.visible) —
	# _alizee_answer reste null sinon, pas de faux "non" persisté.
	if _mere_block.visible:
		StoryVars.m1_report_alizee_transmit = _alizee_answer
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())

	_play_report_terminal()


## Fenêtre système par-dessus le rapport, simulant l'envoi du rapport à Jean
## puis — si le joueur a choisi de prévenir Alizée de la vérité sur sa mère —
## l'envoi de la preuve à Marek (voir _build_report_terminal_lines). Ferme sur
## RelayGhost (voir _open_relayghost_report_chat), dernier temps fort de la
## mission.
func _play_report_terminal() -> void:
	MusicPlayer.play(REPORT_TERMINAL_MUSIC, REPORT_TERMINAL_MUSIC_FADE_SECONDS)

	var console: TerminalConsole = TERMINAL_CONSOLE.instantiate()
	console.lines = _build_report_terminal_lines()
	console.typing_sound = SfxPlayer.TERMINAL_TYPING_SFX
	console.fade_out_on_close = true
	console.close_fade_seconds = REPORT_TERMINAL_CLOSE_FADE_SECONDS
	console.closed.connect(_open_relayghost_report_chat)
	add_child(console)


## Script du terminal d'envoi — jargon technique non traduit quelle que soit
## la langue (même choix que desktop.gd::_build_jean_dump_lines, un vrai
## terminal ne se traduit pas). Chaque commande est suivie d'une vraie sortie
## système ([SYS]/[SUCCESS], voir desktop.gd::_build_jean_dump_lines pour la
## même recette) plutôt qu'un enchaînement sec de commandes sans retour — les
## deux confirmations d'envoi sont en accent (voir _terminal_success_line) à
## la demande explicite du joueur.
func _build_report_terminal_lines() -> Array[TerminalLine]:
	var prompt := _terminal_color_hex(Palette.BORDER_ACCENT)
	var normal := _terminal_color_hex(Palette.TEXT_NORMAL)
	var muted := _terminal_color_hex(Palette.CONSOLE_TEXT)
	var accent := _terminal_color_hex(Palette.TEXT_ACCENT)

	var lines: Array[TerminalLine] = []
	lines.append(_terminal_command_line("apt-get update && apt-get install -y mailutils gpg", prompt, normal))
	lines.append(_terminal_sys_line("mailutils/gpg installés.", muted))
	lines.append(_terminal_command_line("gpg --import /etc/ssl/certs/jean_ranoud_pubkey.asc", prompt, normal))
	lines.append(_terminal_sys_line("Clé publique importée (jean.ranoud@cybercorp.internal).", muted))
	lines.append(TerminalLine.text_line(""))

	# [ et ] échappés en [lb]/[rb] dans le sujet de mail : du BBCode littéral
	# planterait sinon leur affichage (voir rich_text_markup.gd et
	# desktop.gd::_build_hack_pc_mother_login_lines pour le même besoin).
	lines.append(_terminal_command_line("gpg --trust-model always --encrypt -r \"jean.ranoud@cybercorp.internal\" /var/log/whitehat/reports/incident.pdf", prompt, normal))
	lines.append(_terminal_sys_line("Rapport chiffré : incident.pdf.gpg", muted))
	lines.append(_terminal_command_line("echo \"Jean, voici le rapport d'incident.\" | mailx -s \"[lb]URGENT[rb] Rapport PDF\" -a /var/log/whitehat/reports/incident.pdf.gpg j.ranoud@cybercorp.internal", prompt, normal))
	lines.append(TerminalLine.progress_line("incident.pdf.gpg", 3, "1.4MB/s", "00:02"))
	lines.append(_terminal_success_line("Mail envoyé à Jean Ranoud", accent))

	# Uniquement si le joueur a choisi de transmettre la vérité sur sa mère à
	# Alizée (voir _on_validate_pressed) — adressé à Marek, seul contact
	# joignable d'Alizée dans les données du joueur (voir osint_characters.json).
	if _mere_block.visible and _alizee_answer == true:
		lines.append(TerminalLine.text_line(""))
		lines.append(_terminal_command_line("curl --url 'smtp://mail.gomail.com:25' --mail-from 'agent@whitehat.local' --mail-rcpt 'marek.trodan@gomail.com' --upload-file /opt/whitehat/evidence/dump_extracted.txt", prompt, normal))
		lines.append(TerminalLine.progress_line("dump_extracted.txt", 1, "0.9MB/s", "00:01"))
		lines.append(_terminal_success_line("Mail envoyé à Marek Trodan", accent))

	return lines


## "[SYS] <message>" en couleur muette — confirmation neutre entre deux
## commandes, même recette que desktop.gd::_build_jean_dump_lines.
func _terminal_sys_line(message: String, muted: String) -> TerminalLine:
	return TerminalLine.text_line("[color=%s][lb]SYS[rb] %s[/color]" % [muted, message])


## "[SUCCESS] <message>" entièrement en accent — les deux seuls passages que
## le joueur a explicitement demandé de mettre en évidence (envoi à Jean,
## envoi à Marek).
func _terminal_success_line(message: String, accent: String) -> TerminalLine:
	return TerminalLine.text_line("[color=%s][lb]SUCCESS[rb] %s[/color]" % [accent, message])


## "user@whitehat:~$ <commande>" — même prompt/couleurs que desktop.gd, avec
## le son de frappe (voir TerminalConsole.typing_sound) puisque c'est le
## joueur qui "tape" chacune de ces commandes.
func _terminal_command_line(command: String, prompt: String, normal: String) -> TerminalLine:
	return TerminalLine.text_line("[color=%s]user@whitehat:~$[/color] [color=%s]%s[/color]" % [prompt, normal, command], true)


## BBCode hex ("#rrggbb") d'une couleur Palette — même recette que
## desktop.gd::_terminal_color_hex, dupliquée ici plutôt que partagée entre
## scripts pour une seule ligne (voir sfx_player.gd::AMBIENT_SILENT_VOLUME_DB
## pour le même choix).
func _terminal_color_hex(color: Color) -> String:
	return "#%s" % color.to_html(false)


## Dernier temps fort de la mission : RelayGhost referme la boucle une fois le
## rapport parti. Les autres actions du header (Indice/recherche) restent
## indisponibles — set_investigation_controls_visible(false) posé dans _ready
## n'est jamais réactivé sur cet écran, la mission ne reprend pas en arrière.
func _open_relayghost_report_chat() -> void:
	MusicPlayer.stop(REPORT_TERMINAL_MUSIC_FADE_SECONDS)

	var contact := ChatContact.new()
	contact.contact_id = "relayghost_report_m1"
	contact.contact_name = "RelayGhost"
	contact.avatar = RELAYGHOST_AVATAR
	contact.dialogue_resource = RELAYGHOST_REPORT_DIALOGUE

	var window: ChatWindow = CHAT_WINDOW.instantiate()
	window.contacts = [contact]
	window.minimize_requested.connect(_on_report_chat_minimize_requested)
	add_child(window)


## Même recette que desktop.gd::_on_window_minimize_requested (juste un
## restore, pas de re-tri par-dessus d'autres fenêtres puisqu'il n'y en a
## qu'une seule ici) — évite un blocage si le joueur réduit cette fenêtre.
func _on_report_chat_minimize_requested(window: Control, window_title: String) -> void:
	_footer.add_minimized_window(window_title, func() -> void:
		window.show()
	)


## Même principe que desktop.gd::_on_thought_log_button_pressed : une seule
## instance réutilisée, jamais fermée/détruite, juste rafraîchie à chaque clic.
func _on_thought_log_button_pressed() -> void:
	if not is_instance_valid(_thought_log_window):
		_thought_log_window = THOUGHT_LOG_WINDOW.instantiate()
		add_child(_thought_log_window)
	_thought_log_window.refresh()
	_thought_log_window.show()


## La scrollbar hérite par défaut du vert global (voir VScrollBar dans
## main_theme.tres) — recolorée en bleu ici pour rester cohérente avec le
## chrome de cette fenêtre, sans toucher au thème global (donc sans affecter
## les autres fenêtres/écrans). Même recette de duplication que
## chat_window.gd::_apply_color_scheme : on part du style résolu existant
## (marges/coins déjà corrects) et on ne change que la couleur.
func _apply_blue_scrollbar() -> void:
	var scrollbar: VScrollBar = _scroll.get_v_scroll_bar()

	var grabber_style: StyleBoxFlat = scrollbar.get_theme_stylebox("grabber").duplicate()
	grabber_style.bg_color = Palette.CLUE_SOLUTION_BORDER
	var grabber_hover_style: StyleBoxFlat = scrollbar.get_theme_stylebox("grabber_highlight").duplicate()
	grabber_hover_style.bg_color = Palette.TEXT_BLUE_ACCENT
	var track_style: StyleBoxFlat = scrollbar.get_theme_stylebox("scroll").duplicate()
	track_style.bg_color = Color(Palette.CLUE_SOLUTION_BG.r, Palette.CLUE_SOLUTION_BG.g, Palette.CLUE_SOLUTION_BG.b, 0.55)

	scrollbar.add_theme_stylebox_override("grabber", grabber_style)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover_style)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_hover_style)
	scrollbar.add_theme_stylebox_override("scroll", track_style)
	scrollbar.add_theme_stylebox_override("scroll_focus", track_style)


## Blanc par défaut, vert pour la réponse choisie, rouge pour l'autre (voir
## _on_jean_answer/_on_alizee_answer) — recolore la bordure/fond ET le texte
## du bouton, même recette de duplication que chat_window.gd::_set_row_selected.
func _style_choice_button(button: Button, color: Color) -> void:
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(state, color)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(color.r, color.g, color.b, 0.08)
	normal_style.set_border_width_all(2)
	normal_style.border_color = color
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 32
	normal_style.content_margin_right = 32
	normal_style.content_margin_top = 14
	normal_style.content_margin_bottom = 14
	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(color.r, color.g, color.b, 0.18)

	button.add_theme_stylebox_override(&"normal", normal_style)
	button.add_theme_stylebox_override(&"focus", normal_style)
	button.add_theme_stylebox_override(&"hover", hover_style)
	button.add_theme_stylebox_override(&"pressed", hover_style)


func _start_validate_blink() -> void:
	if is_instance_valid(_validate_blink_tween):
		return
	_validate_blink_tween = create_tween()
	_validate_blink_tween.set_loops()
	_validate_blink_tween.set_trans(Tween.TRANS_SINE)
	_validate_blink_tween.tween_property(_validate_button, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	_validate_blink_tween.tween_property(_validate_button, "modulate:a", 1.0, BLINK_SECONDS)


func _stop_validate_blink() -> void:
	if is_instance_valid(_validate_blink_tween):
		_validate_blink_tween.kill()
	_validate_blink_tween = null
	_validate_button.modulate.a = 1.0
