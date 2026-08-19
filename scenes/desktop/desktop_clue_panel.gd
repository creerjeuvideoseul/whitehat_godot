extends Control
class_name DesktopCluePanel
## Panneau permanent ancré au bord droit de l'écran (voir desktop.tscn) —
## distinct des fenêtres de WindowLayer (ChatWindow, ClueBoardWindow...) :
## jamais réduit dans la barre des tâches, toujours présent, seulement
## rétractable sur lui-même. Bordure/coins droits volontairement absents
## (voir StyleBoxFlat_bg/StyleBoxFlat_border_overlay dans la scène,
## border_width_right = 0 et corner_radius_*_right = 0) : le panneau est
## censé se fondre dans le bord de l'écran auquel il est collé plutôt que de
## paraître flotter devant.
##
## Contenu central encore vide pour l'instant (voir _content_list) — prévu
## pour le nouveau système d'indices actifs (branche NewClueSystem), pas
## encore branché ici.

## Largeur du panneau déployé.
const EXPANDED_WIDTH := 300.0
## Largeur qui reste visible une fois rétracté (le reste glisse hors écran,
## le panneau étant déjà collé au bord droit) — juste assez pour rester
## repérable et cliquable, sans prendre de place inutile sur le bureau.
const COLLAPSED_VISIBLE_WIDTH := 30.0
const SLIDE_OFFSET := EXPANDED_WIDTH - COLLAPSED_VISIBLE_WIDTH
const SLIDE_SECONDS := 0.4

@onready var _background: Panel = %Background
@onready var _retract_button: Button = %RetractButton
@onready var _content_list: VBoxContainer = %ContentList
@onready var _title_label: Label = %TitleLabel
## Remplace _title_label une fois rétracté (voir _set_collapsed) : le titre
## complet n'a plus la place de s'afficher correctement dans les
## COLLAPSED_VISIBLE_WIDTH px encore visibles, une flèche seule reste lisible
## et signale clairement qu'un clic rouvre le panneau.
@onready var _collapsed_arrow_label: Label = %CollapsedArrowLabel

var _collapsed: bool = false
var _slide_tween: Tween
## position.x réel du panneau déployé, capturé au démarrage — voir
## _set_collapsed. Ce n'est PAS 0 : le panneau est ancré au bord droit
## (anchor_left = anchor_right = 1.0), donc Godot calcule
## position.x = anchor_left * largeur_parent + offset_left, une valeur bien
## plus grande que 0. Animer vers 0.0 en dur (comme dans une première version
## de ce script) faisait sauter le panneau vers la gauche de l'écran au lieu
## de le glisser légèrement vers la droite.
var _expanded_position_x: float


func _ready() -> void:
	_expanded_position_x = position.x
	_retract_button.pressed.connect(_on_retract_button_pressed)
	_background.gui_input.connect(_on_background_gui_input)


func _on_retract_button_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_set_collapsed(true)


## Seul le fond réagit au clic une fois rétracté (pas tout le Control) : dans
## cet état, seuls les COLLAPSED_VISIBLE_WIDTH px de gauche du fond dépassent
## réellement à l'écran, le reste du panneau (dont RetractButton) étant
## poussé hors du viewport — inutile de distinguer davantage la zone cliquable.
func _on_background_gui_input(event: InputEvent) -> void:
	if not _collapsed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_set_collapsed(false)


## Glissement horizontal relatif à _expanded_position_x — même recette que
## desktop.gd::_minimize_window_with_slide (capturer la position d'origine,
## animer vers origine + décalage, jamais une valeur absolue en dur) pour
## rester visuellement cohérent avec les autres glissements du bureau.
func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_title_label.visible = not collapsed
	_collapsed_arrow_label.visible = collapsed
	# Main seulement quand le fond est réellement cliquable (replié, voir
	# _on_background_gui_input) — flèche curseur normale une fois déployé, le
	# fond n'ayant alors plus d'action propre.
	_background.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if collapsed else Control.CURSOR_ARROW
	if is_instance_valid(_slide_tween):
		_slide_tween.kill()
	var target_x := _expanded_position_x + (SLIDE_OFFSET if collapsed else 0.0)
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position:x", target_x, SLIDE_SECONDS)
