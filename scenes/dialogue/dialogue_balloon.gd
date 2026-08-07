extends CanvasLayer
class_name DialogueBalloon
## Bottom-of-screen dialogue box (Ren'Py style) for Dialogue Manager.
## Reproduces the example balloon's contract (start/next/dialogue_line)
## but skinned for the WHITE HAT look, with voice/localization support
## stripped since this project doesn't use them.

signal dialogue_line_shown(character: String, text: String)

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var auto_start: bool = false
@export var will_block_other_input: bool = true
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

## Nom de personnage -> couleur du pseudo dans l'encart de discussion. Vide
## par défaut (le vert de CharacterLabel dans la scène s'applique alors tel
## quel) — à définir par l'appelant avant start() pour distinguer un
## personnage (ex: Gilles de la Touret en bleu dans l'intro, voir introduction.gd).
var character_name_colors: Dictionary = {}

var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false
## État de is_waiting_for_input avant un show_history_line(), pour le
## restaurer tel quel dans resume_live_line().
var _live_was_waiting_for_input: bool = false

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

var mutation_cooldown: Timer = Timer.new()

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress_label: Label = %ProgressLabel


func _ready() -> void:
	balloon.hide()
	balloon.gui_input.connect(_on_balloon_gui_input)
	DialogueManager.mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action
	responses_menu.response_selected.connect(_on_responses_menu_response_selected)

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		start()


func _unhandled_input(event: InputEvent) -> void:
	# "ui_cancel" reste toujours libre : c'est le raccourci global du menu
	# Options (voir OptionsMenu autoload) — sans cette exception, ÉCHAP ne
	# marchait plus du tout tant qu'une balloon était affichée (ex: l'intro).
	if will_block_other_input and not event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	ClueManager.unlock_from_tags(dialogue_line)
	dialogue_line.text = RichTextMarkup.resolve_important_color(dialogue_line.text)

	progress_label.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = _colored_character_name(dialogue_line.character)

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	dialogue_line_shown.emit(dialogue_line.character, dialogue_line.text)
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		progress_label.show()
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


## Affiche une ligne déjà vue, en lecture seule, sans toucher à l'état réel
## du dialogue en cours (pour un retour en arrière à la molette, voir
## Introduction._rewind()). Le texte apparaît intégralement, sans effet de
## frappe. Utiliser resume_live_line() pour revenir à la ligne réellement en
## cours.
func show_history_line(character: String, text: String) -> void:
	if is_waiting_for_input:
		_live_was_waiting_for_input = true
		is_waiting_for_input = false
	progress_label.hide()

	character_label.visible = not character.is_empty()
	character_label.text = _colored_character_name(character)

	var history_line := DialogueLine.new()
	history_line.text = text
	dialogue_label.dialogue_line = history_line
	dialogue_label.visible_ratio = 1.0


## Restaure l'affichage de la ligne réellement en cours après un ou
## plusieurs show_history_line().
func resume_live_line() -> void:
	if not is_instance_valid(dialogue_line):
		return

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = _colored_character_name(dialogue_line.character)

	dialogue_label.dialogue_line = dialogue_line
	dialogue_label.visible_ratio = 1.0

	if _live_was_waiting_for_input:
		_live_was_waiting_for_input = false
		is_waiting_for_input = true
		progress_label.show()


func _colored_character_name(character: String) -> String:
	if character_name_colors.has(character):
		return "[color=#%s]%s[/color]" % [character_name_colors[character].to_html(false), character]
	return character


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# Ne marque géré que ce qu'on avance réellement — sinon ÉCHAP (ou toute
	# autre touche) était avalé ici sans raison à chaque ligne en attente de
	# clic, empêchant le raccourci global du menu Options de le recevoir.
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		get_viewport().set_input_as_handled()
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)
