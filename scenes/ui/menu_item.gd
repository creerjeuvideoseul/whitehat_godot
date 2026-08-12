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

## Item secondaire, volontairement moins visible que les autres (ex. "Crédits")
## — descend le titre vers le gris au lieu du blanc quasi-pur par défaut, sans
## le rendre grisé/non-cliquable comme set_locked() le ferait.
@export var muted: bool = false:
	set(value):
		muted = value
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
	var title_color := Palette.TEXT_NORMAL
	if disabled:
		title_color = Palette.TEXT_LOCKED
	elif destructive:
		title_color = Palette.TEXT_DANGER
	elif muted:
		title_color = Palette.CONSOLE_TEXT
	_title_label.add_theme_color_override("font_color", title_color)
	_number_label.add_theme_color_override("font_color", Palette.TEXT_LOCKED if disabled else Palette.CONSOLE_TEXT)
