extends Control
class_name HackPcMotherWindow
## Fenêtre "Piratage — PC de la mère", déclenchée depuis le mail crypté de la
## mère (meta_info.Hack_PC_Mother, voir mail_section.gd) — même chrome que
## ClueBoardWindow/OsintWindow (titre, réduction, bordure vive). Contenu
## provisoire : un texte fixe, la vraie mécanique de piratage viendra dans
## une prochaine passe (voir aussi report_generation_screen.gd pour le même
## genre de placeholder).

signal minimize_requested(window: Control, window_title: String)

@onready var _title_label: Label = %TitleLabel
@onready var _minimize_button: Button = %MinimizeButton


func _ready() -> void:
	_minimize_button.pressed.connect(_on_minimize_pressed)


func _on_minimize_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
	minimize_requested.emit(self, _title_label.text)
