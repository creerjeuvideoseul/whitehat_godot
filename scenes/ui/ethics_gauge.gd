extends HBoxContainer
class_name EthicsGauge
## Jauge diégétique remplaçant la coloration vert/rouge des boutons
## Transmettre/Ne pas transmettre de report_generation_screen.gd — une
## aiguille se déplace entre deux pôles nommés selon l'axe touché par le
## choix, plutôt qu'un score "bonne/mauvaise réponse" à lire dans un popup.
##
## Le Slider n'est jamais piloté par le joueur (voir _ready, mouse_filter/
## focus_mode) : sa valeur ne bouge que via set_value(), appelé une fois le
## vrai choix fait ailleurs (voir report_generation_screen.gd::_on_jean_answer/
## _on_alizee_answer). Le remplissage natif d'un HSlider (du bord gauche
## jusqu'à la valeur courante) sert directement de jauge : à -1 (pôle gauche)
## il est quasi vide, à +1 (pôle droit) quasi plein — aucun détournement du
## widget nécessaire.

const NEUTRAL_VALUE := 0.0
const ANIMATE_SECONDS := 0.5

@onready var _left_label: Label = %LeftPoleLabel
@onready var _right_label: Label = %RightPoleLabel
@onready var _slider: HSlider = %Slider

var _tween: Tween


func _ready() -> void:
	# Purement visuel : le joueur ne doit jamais pouvoir faire glisser
	# l'aiguille lui-même, seul set_value() la déplace.
	_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slider.focus_mode = Control.FOCUS_NONE
	_set_pole_emphasis(NEUTRAL_VALUE)


func set_poles(left_text: String, right_text: String) -> void:
	_left_label.text = left_text
	_right_label.text = right_text


## `value` dans [-1, 1] : -1 pôle gauche, +1 pôle droit, 0 neutre (état avant
## tout choix, voir NEUTRAL_VALUE). Anime toujours — cet écran ne restaure
## jamais un choix déjà fait (voir report_generation_screen.gd, pas de
## checkpoint avant "Valider le rapport"), donc aucun besoin d'un mode
## "sans animation" pour une reprise de sauvegarde.
func set_value(value: float) -> void:
	value = clampf(value, -1.0, 1.0)
	if is_instance_valid(_tween):
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_slider, "value", value, ANIMATE_SECONDS)
	_tween.tween_callback(_set_pole_emphasis.bind(value))


## Le pôle vers lequel penche l'aiguille s'éclaire, l'autre s'assourdit —
## remplace le rouge/vert par une simple emphase directionnelle, sans
## jugement de valeur porté par la couleur elle-même.
func _set_pole_emphasis(value: float) -> void:
	var left_color := Palette.CONSOLE_TEXT
	var right_color := Palette.CONSOLE_TEXT
	if value < 0:
		left_color = Palette.TEXT_BLUE_ACCENT
	elif value > 0:
		right_color = Palette.TEXT_BLUE_ACCENT
	_left_label.add_theme_color_override("font_color", left_color)
	_right_label.add_theme_color_override("font_color", right_color)
