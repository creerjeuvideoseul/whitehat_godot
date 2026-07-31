extends Button
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

func _update_title_color() -> void:
	var destructive_color := Color(1.0, 0.36, 0.36)
	var normal_color := Color(0.92, 0.96, 0.94)
	_title_label.add_theme_color_override("font_color", destructive_color if destructive else normal_color)
