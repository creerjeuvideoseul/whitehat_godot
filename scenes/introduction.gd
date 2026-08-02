extends Control
## Cutscene played before login: swaps a full-screen background per dialogue
## line (called from intro.dialogue via `do change_background("...")`) while
## Dialogue Manager drives the bottom textbox.

const INTRO_DIALOGUE: DialogueResource = preload("res://dialogue/intro.dialogue")
const DIALOGUE_BALLOON := "res://scenes/dialogue/dialogue_balloon.tscn"
const IMAGE_DIR := "res://assets/images/"
const IMAGE_EXTENSION := "webp"

@onready var _background: TextureRect = %Background


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, INTRO_DIALOGUE)


## Called from intro.dialogue as `do change_background("wh_intro_fille_tele2")`.
func change_background(image_name: String) -> void:
	var path := "%s%s.%s" % [IMAGE_DIR, image_name, IMAGE_EXTENSION]
	if ResourceLoader.exists(path):
		_background.texture = load(path)
	else:
		push_warning("Introduction: image manquante '%s'" % path)


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if resource != INTRO_DIALOGUE:
		return
	get_tree().change_scene_to_file("res://scenes/login.tscn")
