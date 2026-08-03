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
	_apply_mission()


func _apply_mission() -> void:
	_clue_board.setup(mission_id)
	_question_label.text = tr("CLUEBOARD_TITLE_M%d" % mission_id)


func _on_minimize_pressed() -> void:
	hide()
	minimize_requested.emit(self, _title_label.text)
