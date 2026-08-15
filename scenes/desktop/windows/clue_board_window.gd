extends Control
class_name ClueBoardWindow
## Fenêtre "collecte d'indices" : même chrome (fond/cadre vert, barre de
## titre) et même style d'ancrage (centrée, taille fixe en pixels) que les
## autres fenêtres du bureau (ex. ChatWindow/OsintWindow, voir les ancres de
## la scène) — juste plus grande (2400x1200) puisque le tableau d'enquête
## peut compter plusieurs colonnes de catégories. Le contenu (ClueBoard) est
## générique par mission — voir clue_board.gd — donc réutilisable tel quel
## pour les prochaines missions.
##
## Bouton "×" plutôt que "—" (réduction) : contrairement aux autres fenêtres,
## celle-ci se rouvre toujours au même endroit (le bouton "Indice" du header,
## en permanence visible) — pas besoin d'une icône dans la barre des tâches en
## plus pour la retrouver, se fermer directement suffit (voir desktop.gd,
## _on_clue_button_pressed : l'instance est réutilisée en interne, seule sa
## visibilité change). Déplaçable par la barre de titre comme les autres,
## malgré tout (voir _on_title_bar_gui_input) — sa position n'est pas
## persistée, elle repart centrée à chaque nouvelle ouverture de session.

## Bubbled up to desktop.gd, qui décide ce qu'ouvrir "générer le rapport"
## veut dire (voir report_generation_screen) — cette fenêtre ne connaît que
## son propre bouton.
signal generate_report_requested

## Même recette de clignotement que le bouton Indice du header (voir
## desktop_header.gd::_start_clue_button_blink) — attire l'oeil sur GENERER
## LE RAPPORT dès qu'il devient bleu/cliquable, s'arrête au premier clic.
const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4

@export var mission_id: int = 1:
	set(value):
		mission_id = value
		if is_node_ready():
			_apply_mission()

@onready var _title_bar: PanelContainer = %TitleBar
@onready var _close_button: Button = %CloseButton
@onready var _question_label: Label = %QuestionLabel
@onready var _clue_board: ClueBoard = %ClueBoard
@onready var _generate_report_button: Button = %GenerateReportButton
@onready var _report_confirm_dialog: ConfirmationDialog = %ReportConfirmDialog

var _report_button_blink_tween: Tween
var _dragging: bool = false


func _ready() -> void:
	## Cachée jusqu'à ce que Layout (VBoxContainer) ait fini sa propre passe
	## de mise en page — sinon la toute première frame peut afficher TitleBar
	## avec une taille pas encore stabilisée, contrairement à Background/
	## BorderOverlay (de simples Panel, corrects dès l'entrée dans l'arbre) :
	## coin de la barre de titre décalé par rapport au cadre, visible jusqu'au
	## prochain redraw de cette zone (potentiellement jamais, si rien d'autre
	## n'y change) — voir _reveal_once_settled().
	visible = false
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_generate_report_button.pressed.connect(_on_generate_report_button_pressed)
	## "Non" n'a besoin d'aucun câblage : le bouton Annuler d'un
	## ConfirmationDialog se contente de le cacher (comportement natif
	## d'AcceptDialog), et cette fenêtre n'a jamais été cachée derrière —
	## on s'y retrouve donc automatiquement.
	_report_confirm_dialog.get_cancel_button().text = "COMMON_NO"
	DialogStyle.style_warning_dialog(_report_confirm_dialog)
	_report_confirm_dialog.confirmed.connect(_on_report_confirmed)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	_apply_mission()
	_reveal_once_settled()


## Deux frames d'attente : une pour que Layout termine sa passe de mise en
## page, une seconde par marge de sécurité (le moteur peut s'y prendre à
## plusieurs frames selon la profondeur de l'arbre de conteneurs).
func _reveal_once_settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	visible = true


func _apply_mission() -> void:
	_clue_board.setup(mission_id)
	_question_label.text = tr("CLUEBOARD_TITLE_M%d" % mission_id)
	## Caché tant que l'enquête proprement dite n'a pas commencé (voir
	## ClueManager.has_mission_started) — sinon la question de la mission
	## s'affiche dès la toute première ouverture, avant même d'avoir mis les
	## pieds sur le téléphone d'Alizée.
	_question_label.visible = ClueManager.has_mission_started(mission_id)
	_update_report_button()


## Un indice fraîchement débloqué peut être le tout premier de cette mission
## à suivre la convention "M<mission_id>_..." — révèle alors le titre sans
## attendre une fermeture/réouverture de la fenêtre.
func _on_clue_unlocked(_clue_id: String) -> void:
	if not _question_label.visible:
		_question_label.visible = ClueManager.has_mission_started(mission_id)
	_update_report_button()


## Grisé (PrimaryButton) tant que la résolution de CETTE mission n'est pas
## trouvée, bleu (ImportantButton, voir main_theme.tres) et cliquable une
## fois débloquée — même condition générique que desktop_header.gd, mais
## scopée à mission_id puisque cette fenêtre en a une propre.
func _update_report_button() -> void:
	var unlocked := ClueManager.has_unlocked_mission_solution(mission_id)
	_generate_report_button.disabled = not unlocked
	_generate_report_button.theme_type_variation = &"ImportantButton" if unlocked else &"PrimaryButton"
	if unlocked:
		_start_report_button_blink()
	else:
		_stop_report_button_blink()


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()


## Glisser par la barre de titre, comme OsintWindow/ThoughtLogWindow.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var max_position: Vector2 = get_parent_area_size() - size
		position = (position + event.relative).clamp(Vector2.ZERO, max_position)


## N'émet pas encore generate_report_requested : demande d'abord confirmation
## (voir _on_report_confirmed), puisque passer à l'étape suivante est
## irréversible pour le joueur (voir REPORT_CONFIRM_WARNING).
func _on_generate_report_button_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_stop_report_button_blink()
	_report_confirm_dialog.dialog_text = "%s\n\n%s\n\n%s" % [
		tr("REPORT_CONFIRM_INTENT"), tr("REPORT_CONFIRM_WARNING"), tr("REPORT_CONFIRM_QUESTION")
	]
	_report_confirm_dialog.popup_centered()


func _on_report_confirmed() -> void:
	generate_report_requested.emit()


## Même recette que desktop_header.gd::_start_tor_blink/_start_clue_button_blink.
func _start_report_button_blink() -> void:
	if is_instance_valid(_report_button_blink_tween):
		return
	_report_button_blink_tween = create_tween()
	_report_button_blink_tween.set_loops()
	_report_button_blink_tween.set_trans(Tween.TRANS_SINE)
	_report_button_blink_tween.tween_property(_generate_report_button, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	_report_button_blink_tween.tween_property(_generate_report_button, "modulate:a", 1.0, BLINK_SECONDS)


func _stop_report_button_blink() -> void:
	if is_instance_valid(_report_button_blink_tween):
		_report_button_blink_tween.kill()
	_report_button_blink_tween = null
	_generate_report_button.modulate.a = 1.0
