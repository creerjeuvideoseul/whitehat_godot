extends Control
class_name TerminalConsole
## Boîte de transition façon terminal Linux (1100×680, fond/bords noirs) qui
## déroule une liste de TerminalLine les unes après les autres avec un effet
## de frappe, avant de laisser apparaître un bouton "Fermer". Générique et
## réutilisable : aucun texte n'est en dur ici, tout vient du script passé à
## play() — voir desktop.gd pour le script utilisé après l'appel de Jean.
##
## Ajoutée directement en enfant de la scène appelante (pas de CanvasLayer
## dédié comme OptionsMenu) : c'est une étape de narration ponctuelle propre
## à l'appelant, pas un système global accessible depuis n'importe où.

signal closed
## Même contrat que ChatWindow/ClueBoardWindow/OsintWindow/HackPcMotherWindow
## (minimize_requested(window, window_title)) — n'est émis qu'en mode fenêtré,
## voir window_title.
signal minimize_requested(window: Control, window_title: String)
## Émis une seule fois, juste avant la toute première demande de mot de passe
## (voir login_prompt_text/_play_login_gate) — pas rejoué à chaque tentative
## incorrecte. Seulement pertinent quand login_prompt_text est renseigné.
signal login_gate_started

const LINE_GAP_SECONDS := 0.15
const PROGRESS_STEP_SECONDS := 0.03
## Vitesse de frappe des lignes "tapées" par le joueur (prompts user@/jean@,
## voir TerminalLine.plays_typing_sound) — 4x plus rapide que le défaut de
## DialogueLabel (0.02s/caractère), pour un terminal qui ne traîne pas.
const TYPING_SECONDS_PER_STEP := 0.005
## Les lignes système (sorties d'outils, sans plays_typing_sound) s'écrivent
## 3x plus vite que ci-dessus : c'est le joueur qui "tape" les commandes, pas
## le reste du texte qui défile à l'écran.
const SYSTEM_LINE_TYPING_SECONDS_PER_STEP := TYPING_SECONDS_PER_STEP / 3.0
## Largeur de la colonne "nom de fichier" des lignes PROGRESS, pour aligner
## le pourcentage comme le ferait un vrai scp/rsync.
const FILENAME_COLUMN_WIDTH := 46
## Pause après la dernière ligne avant l'auto-fermeture (show_close_button =
## false), pour laisser le temps de la lire.
const AUTO_CLOSE_DELAY_SECONDS := 0.6
## Fondu (entrée et sortie) du bruitage de frappe autour de chaque ligne qui
## le déclenche (voir TerminalLine.plays_typing_sound) — pas une seule fois
## pour tout le terminal, mais à chaque phrase. Volontairement court : une
## commande tapée dure souvent moins de 0.5s à s'afficher (TYPING_SECONDS_PER_STEP),
## un fondu trop long ne finissait jamais de monter avant d'être coupé par
## stop_ambient(), rendant le son quasi inaudible.
const TYPING_SOUND_FADE_SECONDS := 0.1
## Durée par défaut du fondu de fermeture, si fade_out_on_close est activé —
## voir close_fade_seconds ci-dessous pour l'override par appelant.
const CLOSE_FADE_SECONDS := 0.3

## Le script à dérouler — à définir avant que la scène entre dans l'arbre
## (comme ClueBoardWindow.mission_id) : _ready() s'en sert directement, pas
## besoin d'appeler quoi que ce soit depuis l'appelant après add_child().
var lines: Array[TerminalLine] = []
## Titre affiché en en-tête (clé de traduction ou texte déjà résolu, comme
## CloseButton.text) — masqué si vide. À définir avant add_child(), comme
## `lines`.
var title: String = ""
## Si false, la séquence s'auto-termine (émet `closed`, se libère) une fois
## la dernière ligne affichée, sans bouton "Fermer" — pour un écran qu'on ne
## fait que regarder (ex: boot système, voir Introduction). À définir avant
## add_child(), comme `lines`.
var show_close_button: bool = true
## Bruitage de frappe au clavier (fondu, voir SfxPlayer et TYPING_SOUND_FADE_SECONDS),
## joué uniquement pendant les lignes marquées TerminalLine.plays_typing_sound
## (les prompts user@/jean@, pas les sorties système) — laissé à null par
## défaut : ne le renseigner que quand la séquence simule une vraie saisie du
## joueur (voir desktop.gd, terminal après Jean Ranoud). Le boot système
## après l'intro le laisse à null car le joueur n'y tape rien. À définir
## avant add_child(), comme `lines`.
var typing_sound: AudioStream = null
## Si vrai, la fermeture (bouton ou auto-fermeture) fait un fondu de tout le
## terminal vers la transparence avant de se libérer, au lieu de disparaître
## d'un coup — laissé à false par défaut (comportement inchangé, ex: le boot
## système de l'intro). Activé pour le terminal après Jean Ranoud (voir
## desktop.gd), qui enchaîne sur la transition "analyse en cours"
## (AnalysisTransition) : la boîte, déjà noire, se fond ainsi dans l'écran
## d'analyse plutôt que de disparaître brutalement juste avant qu'il
## n'apparaisse. À définir avant add_child(), comme `lines`.
var fade_out_on_close: bool = false
## Durée du fondu ci-dessus — valeur par défaut (CLOSE_FADE_SECONDS) inchangée
## pour les appelants existants (dump de Jean), seul le terminal du rapport
## final (report_generation_screen.gd) l'allonge pour un fondu plus posé
## avant l'arrivée de RelayGhost. À définir avant add_child(), comme `lines`.
var close_fade_seconds: float = CLOSE_FADE_SECONDS
## BBCode déjà formé (voir `lines` plus haut) retapé en boucle avant d'attendre
## un mot de passe — ex. "Password for Christine@180.252.12.44:". Laissé vide
## par défaut : aucun palier "mot de passe", le terminal se comporte comme
## avant (bouton Fermer ou auto-fermeture, voir _play()). Si renseigné, aucun
## bouton Fermer n'apparaît : la seule sortie possible est un mot de passe
## correct (voir _play_login_gate). À définir avant add_child(), comme `lines`.
var login_prompt_text: String = ""
## Valeur de référence comparée à la saisie du joueur, normalisée via
## _normalize_login_password (insensible à la casse, "_" et espace
## interchangeables) — permet un copier-coller depuis une source en jeu (ex.
## une fiche OSINT) sans se soucier du séparateur exact. À définir avant
## add_child(), comme `lines`.
var login_expected_password: String = ""
## BBCode déjà formé (voir `lines`) affiché après une tentative incorrecte,
## avant de redemander le mot de passe (autant de tentatives que voulu). À
## définir avant add_child(), comme `lines`.
var login_wrong_message: String = ""
## Titre affiché dans une vraie barre de fenêtre réductible (voir
## minimize_requested), à la place du cadre modal habituel (Backdrop assombri
## qui bloque tout le reste, pas de réduction possible) — laissé vide par
## défaut : comportement inchangé (boot système de l'intro, dump de Jean).
## Si renseigné, le terminal devient une fenêtre comme les autres
## (ClueBoardWindow, OsintWindow...) : réductible dans la barre des tâches
## via desktop.gd._open_window(), ce qui laisse le joueur aller consulter
## autre chose (ex. un mail pour y trouver un mot de passe) sans perdre sa
## progression dans le terminal. À définir avant add_child(), comme `lines`.
var window_title: String = ""
## Taille de la boîte centrée (voir Box dans terminal_console.tscn, dont
## c'est la valeur par défaut) — à définir avant add_child(), comme `lines`,
## pour un appelant qui a besoin de plus de place (ex. le terminal de
## connexion RDP du PC de la mère, voir desktop.gd) sans agrandir les autres
## usages (boot système de l'intro, dump de Jean) qui partagent cette même scène.
var box_size: Vector2 = Vector2(1100.0, 680.0)
## Ajouté à la taille de police par défaut du titre et de chaque ligne (voir
## _add_label/_add_login_line_edit), sans toucher aux couleurs — laissé à 0
## par défaut (comportement inchangé pour les usages existants : dump de
## Jean, connexion RDP...). À définir avant add_child(), comme `lines`, pour
## un appelant qui a besoin d'un texte plus grand (ex. le boot système plein
## écran, voir system_boot_screen.gd) sans agrandir les autres usages.
var font_size_boost: int = 0

@onready var _backdrop: ColorRect = $Backdrop
@onready var _box: Control = $Box
@onready var _title_label: Label = %TitleLabel
@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _lines_list: VBoxContainer = %LinesList
@onready var _close_button: Button = %CloseButton

var _current_label: DialogueLabel = null


func _ready() -> void:
	_box.offset_left = -box_size.x * 0.5
	_box.offset_right = box_size.x * 0.5
	_box.offset_top = -box_size.y * 0.5
	_box.offset_bottom = box_size.y * 0.5
	_title_label.visible = not title.is_empty()
	_title_label.text = title
	if font_size_boost != 0:
		_title_label.add_theme_font_size_override("font_size", _title_label.get_theme_font_size("font_size") + font_size_boost)
	_close_button.hide()
	_close_button.pressed.connect(_on_close_pressed)
	gui_input.connect(_on_gui_input)
	if not window_title.is_empty():
		_setup_window_chrome()
	_play()


## Bascule du cadre modal (Backdrop assombri plein écran, bloque tout le
## reste) vers une vraie fenêtre réductible : ajoute une barre de titre avec
## un bouton "—" au-dessus du contenu existant, plutôt que de dupliquer toute
## la scène. mouse_filter passe à IGNORE sur la racine ET sur Backdrop (plein
## écran tous les deux) pour qu'un clic en dehors de la boîte traverse
## jusqu'à ce qu'il y a en dessous (ex. le téléphone d'Alizée) au lieu d'être
## avalé par cette zone — Backdrop reste visible (retour joueur : le bureau
## derrière doit rester assombri comme les autres fenêtres système, même sans
## bloquer les clics ni empêcher la réduction via le bouton "—").
func _setup_window_chrome() -> void:
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)

	var bar_title := Label.new()
	bar_title.text = window_title
	bar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_title.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	bar_title.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE)
	bar.add_child(bar_title)

	var minimize_button := Button.new()
	minimize_button.text = "—"
	minimize_button.custom_minimum_size = Vector2(44, 44)
	minimize_button.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	minimize_button.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE)
	var minimize_hover := StyleBoxFlat.new()
	minimize_hover.bg_color = Color(1, 1, 1, 0.08)
	minimize_hover.corner_radius_top_left = 4
	minimize_hover.corner_radius_top_right = 4
	minimize_hover.corner_radius_bottom_left = 4
	minimize_hover.corner_radius_bottom_right = 4
	minimize_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	minimize_button.add_theme_stylebox_override("hover", minimize_hover)
	minimize_button.add_theme_stylebox_override("pressed", minimize_hover)
	minimize_button.add_theme_stylebox_override("focus", minimize_hover)
	minimize_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		hide()
		minimize_requested.emit(self, window_title)
	)
	bar.add_child(minimize_button)

	var separator := ColorRect.new()
	separator.color = Palette.BORDER_ACCENT
	separator.custom_minimum_size = Vector2(0, 2)

	var layout := _title_label.get_parent()
	layout.add_child(separator)
	layout.move_child(separator, 0)
	layout.add_child(bar)
	layout.move_child(bar, 0)


## Déroule les lignes dans l'ordre, puis affiche le bouton "Fermer" — ou
## s'auto-ferme directement si show_close_button est à false.
func _play() -> void:
	for line in lines:
		if line.kind == TerminalLine.Kind.PROGRESS:
			await _play_progress_line(line)
		else:
			await _play_text_line(line)
		await get_tree().create_timer(LINE_GAP_SECONDS).timeout

	if not login_prompt_text.is_empty():
		await _play_login_gate()
		_on_close_pressed()
		return

	if show_close_button:
		_close_button.show()
		_close_button.grab_focus()
	else:
		await get_tree().create_timer(AUTO_CLOSE_DELAY_SECONDS).timeout
		_on_close_pressed()


## Un clic termine instantanément la ligne en cours de frappe, comme dans
## ConversationView — pratique une fois le script déjà lu une première fois.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(_current_label) and _current_label.is_typing:
			_current_label.skip_typing()


func _play_text_line(line: TerminalLine) -> void:
	var label := _add_label()
	var dialogue_line := DialogueLine.new()
	dialogue_line.text = line.text
	label.dialogue_line = dialogue_line
	label.seconds_per_step = TYPING_SECONDS_PER_STEP if line.plays_typing_sound else SYSTEM_LINE_TYPING_SECONDS_PER_STEP

	var plays_sound := line.plays_typing_sound and typing_sound != null
	if plays_sound:
		SfxPlayer.play_ambient(typing_sound, TYPING_SOUND_FADE_SECONDS)

	_current_label = label
	label.type_out()
	await label.finished_typing
	_current_label = null

	if plays_sound:
		SfxPlayer.stop_ambient(TYPING_SOUND_FADE_SECONDS)


## Réécrit la même ligne à intervalles réguliers en interpolant pourcentage,
## Mo transférés et temps écoulé jusqu'aux valeurs finales de `line`.
func _play_progress_line(line: TerminalLine) -> void:
	var label := _add_label()
	var final_seconds := _parse_mmss(line.progress_total_time)
	var elapsed := 0.0

	while elapsed < line.progress_seconds:
		elapsed = minf(elapsed + PROGRESS_STEP_SECONDS, line.progress_seconds)
		var t: float = elapsed / line.progress_seconds
		label.text = _format_progress_line(line, t, final_seconds)
		_scroll_to_bottom()
		await get_tree().create_timer(PROGRESS_STEP_SECONDS).timeout


func _format_progress_line(line: TerminalLine, t: float, final_seconds: float) -> String:
	var percent := int(round(lerp(0.0, 100.0, t)))
	var mb := int(round(lerp(0.0, float(line.progress_total_mb), t)))
	var elapsed_str := _format_mmss(lerp(0.0, final_seconds, t))
	var filename_col: String = line.progress_column_text.rpad(FILENAME_COLUMN_WIDTH)
	var muted := "#%s" % Palette.CONSOLE_TEXT.to_html(false)
	var accent := "#%s" % Palette.TEXT_ACCENT.to_html(false)
	var stats := "%dMB  %s   %s" % [mb, line.progress_speed_text, elapsed_str]
	return "[color=%s]%s[/color][color=%s]%3d%%[/color][color=%s] %s[/color]" % [muted, filename_col, accent, percent, muted, stats]


func _parse_mmss(value: String) -> float:
	var parts := value.split(":")
	return float(parts[0]) * 60.0 + float(parts[1])


func _format_mmss(total_seconds: float) -> String:
	var seconds := int(round(total_seconds))
	return "%02d:%02d" % [seconds / 60, seconds % 60]


## Retape le prompt puis attend une saisie du joueur (Entrée pour valider,
## autant de tentatives que voulu) jusqu'à un mot de passe correct — voir
## login_prompt_text/login_expected_password/login_wrong_message. C'est la
## seule façon de sortir de cette boucle : pas de bouton Fermer tant que ce
## mode est actif (voir _play()).
func _play_login_gate() -> void:
	login_gate_started.emit()
	var expected := _normalize_login_password(login_expected_password)
	while true:
		await _play_text_line(TerminalLine.text_line(login_prompt_text))
		var line_edit := _add_login_line_edit()
		line_edit.grab_focus()

		while true:
			var entered: String = await line_edit.text_submitted
			if entered.strip_edges().is_empty():
				continue
			if _normalize_login_password(entered) == expected:
				return
			SfxPlayer.play(SfxPlayer.ACCESS_DENIED_SFX)
			line_edit.editable = false
			await _play_text_line(TerminalLine.text_line(login_wrong_message))
			break

		await get_tree().create_timer(LINE_GAP_SECONDS).timeout


## Champ de saisie "en ligne" dans le terminal : fond transparent (se fond
## dans le noir de la boîte, comme le reste du contenu) et texte masqué,
## comme un vrai prompt de mot de passe.
func _add_login_line_edit() -> LineEdit:
	var line_edit := LineEdit.new()
	line_edit.secret = true
	line_edit.caret_blink = true
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.add_theme_font_size_override("font_size", Palette.SIZE_SMALL + font_size_boost)
	line_edit.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	line_edit.add_theme_color_override("caret_color", Palette.BORDER_ACCENT)
	# Curseur "bloc" façon terminal plutôt que la fine barre par défaut — bien
	# visible, clignote tout seul (caret_blink ci-dessus) tant qu'aucune touche
	# n'est pressée, pour signaler que le système attend une saisie.
	line_edit.add_theme_constant_override("caret_width", 12)
	var empty_style := StyleBoxEmpty.new()
	line_edit.add_theme_stylebox_override("normal", empty_style)
	line_edit.add_theme_stylebox_override("focus", empty_style)

	_lines_list.add_child(line_edit)
	_scroll_to_bottom()
	return line_edit


## Insensible à la casse, "_" et espace interchangeables (ex. "Putriku_tersayang"
## == "putriku tersayang") — permet un copier-coller depuis une source en jeu
## (ex. une fiche OSINT) sans se soucier du séparateur exact utilisé côté données.
func _normalize_login_password(text: String) -> String:
	var normalized := text.strip_edges().to_lower().replace("_", " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized


func _add_label() -> DialogueLabel:
	var label := DialogueLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.seconds_per_step = TYPING_SECONDS_PER_STEP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_SMALL + font_size_boost)

	_lines_list.add_child(label)
	_scroll_to_bottom()
	return label


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


func _on_close_pressed() -> void:
	if fade_out_on_close:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, close_fade_seconds)
		await tween.finished
	closed.emit()
	queue_free()
