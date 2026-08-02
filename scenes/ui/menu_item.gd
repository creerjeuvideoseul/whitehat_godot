extends Button
class_name MenuItem
## A single numbered entry in the main menu list ("01  Nouvelle partie").
## The visual highlight (background/border) is handled entirely by the
## Button's normal/hover/focus/pressed StyleBoxes set in menu_item.tscn.

@export var index_number: String = "01":
	set(value):
		index_number = value
		if is_node_ready():
			_number_label.text = value

@export var title_text: String = "Item":
	set(value):
		title_text = value
		if is_node_ready():
			_title_label.text = value

@export var destructive: bool = false:
	set(value):
		destructive = value
		if is_node_ready():
			_update_title_color()

@onready var _number_label: Label = %NumberLabel
@onready var _title_label: Label = %TitleLabel

func _ready() -> void:
	_number_label.text = index_number
	_title_label.text = title_text
	_update_title_color()

## Grey the entry out and make it unclickable, e.g. "Continuer" before any
## save exists. Distinct from the inherited `disabled`, which alone wouldn't
## repaint the manually-colored title/number labels.
func set_locked(is_locked: bool) -> void:
	disabled = is_locked
	focus_mode = FOCUS_NONE if is_locked else FOCUS_ALL
	_update_title_color()

func _update_title_color() -> void:
	var locked_color := Color(0.4, 0.45, 0.42)
	var destructive_color := Color(1.0, 0.36, 0.36)
	var normal_color := Color(0.92, 0.96, 0.94)
	var title_color := normal_color
	if disabled:
		title_color = locked_color
	elif destructive:
		title_color = destructive_color
	_title_label.add_theme_color_override("font_color", title_color)
	_number_label.add_theme_color_override("font_color", locked_color if disabled else Color(0.55, 0.63, 0.58))
