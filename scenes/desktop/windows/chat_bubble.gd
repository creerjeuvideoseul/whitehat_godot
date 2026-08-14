extends PanelContainer
class_name ChatBubble
## A single message bubble: hugs short text, wraps at BUBBLE_MAX_WIDTH for
## longer ones. The typing animation itself is DialogueLabel's own (reused
## as-is via its `dialogue_line` property) — this component only owns the
## bubble's color and width, not how its text gets revealed.

const BUBBLE_MAX_WIDTH := 640.0

@onready var _label: DialogueLabel = %DialogueLabel


## Feeds the line into the inner label and sizes the bubble to it. Returns
## the label so the caller can decide how to reveal it (type_out() for a
## live line, or leave it fully visible when replaying saved history).
## other_color lets each contact have their own bubble tint (e.g. Jean's
## blue vs. RelayGhost's default green) — irrelevant when is_player is true.
func configure(line: DialogueLine, is_player: bool, other_color: Color = Palette.BUBBLE_OTHER) -> DialogueLabel:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BUBBLE_PLAYER if is_player else other_color
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	_label.dialogue_line = line
	_size_to_content(line.text)

	return _label


func _size_to_content(text: String) -> void:
	var font: Font = _label.get_theme_font(&"normal_font")
	var font_size: int = _label.get_theme_font_size(&"normal_font_size")
	var natural_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_label.custom_minimum_size.x = minf(natural_width, BUBBLE_MAX_WIDTH)
