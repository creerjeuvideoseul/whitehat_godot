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
## Les conséquences réelles du choix (score éthique/popularité, argent, voir
## la bible de design) restent à câbler dans une prochaine passe — ce script
## se contente pour l'instant de verrouiller les réponses une fois validées.

const THOUGHT_LOG_WINDOW := preload("res://scenes/desktop/windows/thought_log_window.tscn")
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
	_jean_explanation_label.text = tr("REPORT_M1_JEAN_EXPLANATION_YES" if is_yes else "REPORT_M1_JEAN_EXPLANATION_NO")
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
## étape) — les conséquences réelles du rapport restent à implémenter.
func _on_validate_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_stop_validate_blink()
	_validate_button.disabled = true
	_jean_yes_button.disabled = true
	_jean_no_button.disabled = true
	_alizee_yes_button.disabled = true
	_alizee_no_button.disabled = true


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
