extends Control
class_name ClueBoardWindow
## Fenêtre "collecte d'indices" : même chrome (fond/cadre vert, barre de
## titre, réduction) que les autres fenêtres du bureau (ex. ChatWindow), mais
## prend 90% de l'espace du bureau et reste centrée (voir les ancres de la
## scène). Le contenu (ClueBoard) est générique par mission — voir
## clue_board.gd — donc réutilisable tel quel pour les prochaines missions.

signal minimize_requested(window: Control, window_title: String)

@export var mission_id: int = 1:
	set(value):
		mission_id = value
		if is_node_ready():
			_apply_mission()

@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _question_label: Label = %QuestionLabel
@onready var _clue_board: ClueBoard = %ClueBoard


func _ready() -> void:
	_minimize_button.pressed.connect(_on_minimize_pressed)
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


## Un indice fraîchement débloqué peut être le tout premier de cette mission
## à suivre la convention "M<mission_id>_..." — révèle alors le titre sans
## attendre une fermeture/réouverture de la fenêtre.
func _on_clue_unlocked(_clue_id: String) -> void:
	if not _question_label.visible:
		_question_label.visible = ClueManager.has_mission_started(mission_id)


func _on_minimize_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
	minimize_requested.emit(self, _title_label.text)
