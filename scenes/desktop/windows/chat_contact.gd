extends Resource
class_name ChatContact
## Authored data for one contact inside a ChatWindow: who they are, which
## dialogue resource drives their conversation, and what color their
## message bubbles use — so contacts stay visually distinct from each
## other even though they share the same window.

@export var contact_id: String = ""
@export var contact_name: String = ""
@export var avatar: Texture2D
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title: String = "start"
@export var bubble_color: Color = Palette.BUBBLE_OTHER
