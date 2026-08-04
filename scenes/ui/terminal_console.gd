extends Control
class_name TerminalConsole
## Boîte de transition façon terminal Linux (900×600, fond/bords noirs) qui
## déroule une liste de TerminalLine les unes après les autres avec un effet
## de frappe, avant de laisser apparaître un bouton "Fermer". Générique et
## réutilisable : aucun texte n'est en dur ici, tout vient du script passé à
## play() — voir desktop.gd pour le script utilisé après l'appel de Jean.
##
## Ajoutée directement en enfant de la scène appelante (pas de CanvasLayer
## dédié comme OptionsMenu) : c'est une étape de narration ponctuelle propre
## à l'appelant, pas un système global accessible depuis n'importe où.

signal closed

const LINE_GAP_SECONDS := 0.15
const PROGRESS_STEP_SECONDS := 0.03
## Vitesse de frappe des lignes texte — 2x plus rapide que le défaut de
## DialogueLabel (0.02s/caractère), pour un terminal qui ne traîne pas.
const TYPING_SECONDS_PER_STEP := 0.01
## Largeur de la colonne "nom de fichier" des lignes PROGRESS, pour aligner
## le pourcentage comme le ferait un vrai scp/rsync.
const FILENAME_COLUMN_WIDTH := 46
## Pause après la dernière ligne avant l'auto-fermeture (show_close_button =
## false), pour laisser le temps de la lire.
const AUTO_CLOSE_DELAY_SECONDS := 0.6

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

@onready var _title_label: Label = %TitleLabel
@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _lines_list: VBoxContainer = %LinesList
@onready var _close_button: Button = %CloseButton

var _current_label: DialogueLabel = null


func _ready() -> void:
	_title_label.visible = not title.is_empty()
	_title_label.text = title
	_close_button.hide()
	_close_button.pressed.connect(_on_close_pressed)
	gui_input.connect(_on_gui_input)
	_play()


## Déroule les lignes dans l'ordre, puis affiche le bouton "Fermer" — ou
## s'auto-ferme directement si show_close_button est à false.
func _play() -> void:
	for line in lines:
		if line.kind == TerminalLine.Kind.PROGRESS:
			await _play_progress_line(line)
		else:
			await _play_text_line(line)
		await get_tree().create_timer(LINE_GAP_SECONDS).timeout

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

	_current_label = label
	label.type_out()
	await label.finished_typing
	_current_label = null


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


func _add_label() -> DialogueLabel:
	var label := DialogueLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.seconds_per_step = TYPING_SECONDS_PER_STEP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_SMALL)

	_lines_list.add_child(label)
	_scroll_to_bottom()
	return label


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
