extends Control
## Cutscene played before login: swaps a full-screen background per dialogue
## line (called from intro.dialogue via `do change_background("...")`) while
## Dialogue Manager drives the bottom textbox.

const INTRO_DIALOGUE: DialogueResource = preload("res://dialogue/intro.dialogue")
const DIALOGUE_BALLOON := "res://scenes/dialogue/dialogue_balloon.tscn"

## Preloaded (not built from a string path at runtime) so moving these files
## in the editor updates these references automatically, the same way it
## already keeps scene/resource references in sync — a plain "folder +
## name + extension" string has no such tracking, which is what silently
## broke this the last time the images moved.
const BACKGROUNDS := {
	"wh_intro_fille_tele2": preload("res://assets/images_intro/wh_intro_fille_tele2.webp"),
	"wh_show_television_triste3": preload("res://assets/images_intro/wh_show_television_triste3.webp"),
	"wh_intro_femme_colere2": preload("res://assets/images_intro/wh_intro_femme_colere2.webp"),
	"wh_show_television_homme1": preload("res://assets/images_intro/wh_show_television_homme1.webp"),
	"wh_avec_ordi_quantique": preload("res://assets/images_intro/wh_avec_ordi_quantique.webp"),
	"wh_intro_femme_tourne_oeil": preload("res://assets/images_intro/wh_intro_femme_tourne_oeil.webp"),
	"wh_show_television_homme3": preload("res://assets/images_intro/wh_show_television_homme3.webp"),
	"wh_show_television_enerve2": preload("res://assets/images_intro/wh_show_television_enerve2.webp"),
	"wh_show_television_homme2": preload("res://assets/images_intro/wh_show_television_homme2.webp"),
	"wh_show_television_homme_enerve": preload("res://assets/images_intro/wh_show_television_homme_enerve.webp"),
}

@onready var _background: TextureRect = %Background


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, INTRO_DIALOGUE)


## Called from intro.dialogue as `do change_background("wh_intro_fille_tele2")`.
func change_background(image_name: String) -> void:
	if BACKGROUNDS.has(image_name):
		_background.texture = BACKGROUNDS[image_name]
	else:
		push_warning("Introduction: image manquante '%s'" % image_name)


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if resource != INTRO_DIALOGUE:
		return
	get_tree().change_scene_to_file("res://scenes/login.tscn")
