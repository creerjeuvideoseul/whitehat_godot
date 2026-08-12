extends ColorRect
class_name ReportGenerationScreen
## Écran de transition plein écran ouvert par ClueBoardWindow.GenerateReportButton
## (voir desktop.gd::_on_generate_report_requested) — pour l'instant un simple
## texte, sans logique de génération réelle : la suite du flux "rapport de
## mission" viendra dans une prochaine passe.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
