extends ColorRect
class_name AnalysisTransition
## Transition "analyse en cours" entre la fermeture du terminal système et
## l'apparition du téléphone d'Alizée : prolonge le langage visuel déjà
## utilisé par TerminalConsole (barre de progression façon scp/rsync) plutôt
## que d'introduire un nouvel univers visuel — voir desktop.gd. Générique et
## réutilisable comme TerminalConsole/PlayerThought : s'ajoute en plein cadre
## du Control cible (ex: desktop.gd l'ajoute à WindowLayer pour ne couvrir
## que le bureau central, ni le header ni le footer), joue seule pendant
## TOTAL_SECONDS, puis émet `finished` et se libère — rien à gérer côté
## appelant à part attendre le signal.

signal finished

const FILL_SECONDS := 1.6
const HOLD_SECONDS := 0.2
const FADE_OUT_SECONDS := 0.2
## Exposée pour que l'appelant (desktop.gd) puisse calculer un délai sans
## dupliquer ces trois chiffres.
const TOTAL_SECONDS := FILL_SECONDS + HOLD_SECONDS + FADE_OUT_SECONDS

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _percent_label: Label = %PercentLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_progress(0.0)

	var fill_tween := create_tween()
	fill_tween.tween_method(_set_progress, 0.0, 100.0, FILL_SECONDS)
	await fill_tween.finished

	await get_tree().create_timer(HOLD_SECONDS).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	await fade_tween.finished

	finished.emit()
	queue_free()


func _set_progress(value: float) -> void:
	_progress_bar.value = value
	_percent_label.text = "%d%%" % int(round(value))
