extends Control
class_name ClueBoardWindow
## Fenêtre "collecte d'indices" : même chrome (fond/cadre vert, barre de
## titre) que les autres fenêtres du bureau (ex. ChatWindow), mais prend 90%
## de l'espace du bureau et reste centrée (voir les ancres de la scène). Le
## contenu (ClueBoard) est générique par mission — voir clue_board.gd — donc
## réutilisable tel quel pour les prochaines missions.
##
## Bouton "×" plutôt que "—" (réduction) : contrairement aux autres fenêtres,
## celle-ci se rouvre toujours au même endroit (le bouton "Indice" du header,
## en permanence visible) — pas besoin d'une icône dans la barre des tâches en
## plus pour la retrouver, se fermer directement suffit (voir desktop.gd,
## _on_clue_button_pressed : l'instance est réutilisée en interne, seule sa
## visibilité change).

## Bubbled up to desktop.gd, qui décide ce qu'ouvrir "générer le rapport"
## veut dire (voir report_generation_screen) — cette fenêtre ne connaît que
## son propre bouton.
signal generate_report_requested

@export var mission_id: int = 1:
	set(value):
		mission_id = value
		if is_node_ready():
			_apply_mission()

@onready var _close_button: Button = %CloseButton
@onready var _question_label: Label = %QuestionLabel
@onready var _clue_board: ClueBoard = %ClueBoard
@onready var _generate_report_button: Button = %GenerateReportButton


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_generate_report_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		generate_report_requested.emit()
	)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	_apply_mission()


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


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
