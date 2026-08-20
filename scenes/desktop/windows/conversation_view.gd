extends MarginContainer
class_name ConversationView
## One contact's message thread inside a ChatWindow: scrolling bubble list,
## typing indicator, response choices, connection status line. A ChatWindow
## owns one of these per contact and shows/hides them on switch — each view
## runs its own dialogue flow independently, so switching away mid-typing
## doesn't interrupt anything, it just isn't watched for a moment.

signal choice_shown
signal conversation_finished

const CHAT_BUBBLE := preload("res://scenes/desktop/windows/chat_bubble.tscn")
const PLAYER_CHARACTER := "Player"
## Plain console-style line (no bubble, no typing indicator) — connection
## status, or the player-character's own private/system-level asides.
const SYSTEM_CHARACTER := "System"
const TYPING_INDICATOR_SECONDS := 0.9
## How long "Communication cryptée en réception..." stays up before the
## conversation actually starts — long enough to actually read it.
const CONNECTING_LINE_SECONDS := 1.2

@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _messages_list: VBoxContainer = %MessagesList
@onready var _responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var _response_template: Button = %ResponseTemplate

var _contact: ChatContact
var _log: Array = []
var _current_label: DialogueLabel = null
var _connecting_line: Label = null
## Ressource actuellement parcourue par _advance() : dialogue_resource
## pendant le flux normal, help_dialogue_resource pendant un appel à
## trigger_help() — les deux ne cohabitent jamais (voir gating du bouton
## AIDE dans desktop.gd, qui n'apparaît qu'une fois dialogue_resource fini).
var _active_dialogue_resource: DialogueResource
## Quoi appeler quand _active_dialogue_resource atteint sa fin — distinct
## selon le flux en cours (_on_conversation_finished vs _on_help_finished),
## assigné juste avant chaque appel à _advance() côté setup()/trigger_help().
var _pending_on_finished: Callable


func _ready() -> void:
	_responses_menu.response_template = _response_template
	_responses_menu.response_selected.connect(_on_response_selected)
	gui_input.connect(_on_gui_input)


## Starts (or replays) this contact's conversation. Called once by the
## owning ChatWindow right after instantiation.
func setup(contact: ChatContact) -> void:
	_contact = contact
	if SaveManager.is_conversation_complete(_contact.contact_id):
		_replay_saved_log()
	else:
		_show_connecting_line()
		await get_tree().create_timer(CONNECTING_LINE_SECONDS).timeout
		_active_dialogue_resource = _contact.dialogue_resource
		_pending_on_finished = _on_conversation_finished
		_advance(_contact.dialogue_start_title)


## Rejoue help_dialogue_resource depuis son titre (bouton AIDE du footer, voir
## desktop.gd::_on_help_button_pressed) : ajoute la suite au fil déjà affiché,
## sans jamais déclencher les effets de fin de conversation normale (ex.
## révélation de Jean, voir desktop.gd::_build_chat_window) — seulement
## persister le log grandissant (voir _on_help_finished). Rappelable autant de
## fois que voulu : un fichier .dialogue n'a aucune notion "déjà joué", chaque
## appel repart du tout début du titre. Sans effet si ce contact n'a pas de
## contenu d'aide (voir ChatContact.help_dialogue_resource).
func trigger_help() -> void:
	if _contact.help_dialogue_resource == null:
		return
	_active_dialogue_resource = _contact.help_dialogue_resource
	_pending_on_finished = _on_help_finished
	await _advance(_contact.help_dialogue_start_title)


## Anywhere in this view: a click completes the line currently typing out,
## instead of waiting for it. Buttons (responses) consume their own clicks
## first, so this only fires on empty space / bubble clicks.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(_current_label) and _current_label.is_typing:
			_current_label.skip_typing()


func _show_connecting_line() -> void:
	_connecting_line = Label.new()
	_connecting_line.text = "CHAT_CONNECTING_LINE"
	_connecting_line.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	_connecting_line.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	_messages_list.add_child(_connecting_line)
	_messages_list.move_child(_connecting_line, _responses_menu.get_index())
	_scroll_to_bottom()


func _clear_connecting_line() -> void:
	if is_instance_valid(_connecting_line):
		_connecting_line.queue_free()
		_connecting_line = null


func _replay_saved_log() -> void:
	for entry in SaveManager.get_conversation_log(_contact.contact_id):
		var line := DialogueLine.new()
		line.character = entry.character
		line.text = entry.text
		if entry.character == SYSTEM_CHARACTER:
			var label := _add_console_line(line)
			label.visible_ratio = 1.0
		else:
			_add_bubble(line, entry.character == PLAYER_CHARACTER)
		# Sans ça, _log restait vide après un rejeu : un trigger_help() lancé
		# plus tard sur cette même vue (voir _on_help_finished) écrasait alors
		# tout le journal sauvegardé avec seulement l'échange d'aide, effaçant
		# l'historique déjà rejoué (bug constaté sur "relayghost" : le journal
		# persisté ne contenait plus que la dernière demande d'aide).
		_log.append({ "character": entry.character, "text": entry.text })
	_scroll_to_bottom()


func _advance(next_id: String) -> void:
	var line: DialogueLine = await _active_dialogue_resource.get_next_dialogue_line(next_id, [self])
	if line == null:
		_pending_on_finished.call()
		return
	await _display_line(line)


func _display_line(line: DialogueLine) -> void:
	_clear_connecting_line()
	## L'indice éventuel de cette ligne (tag [#indice=xxx]) ne se débloque plus
	## à l'affichage mais au clic sur le passage color=indice correspondant
	## (voir resolve_dialogue_colors/wire_indice_interactions) — même
	## changement que dialogue_balloon.gd.
	var clue_id := line.get_tag_value("indice") if line.has_tag("indice") else ""
	var raw_text := line.text
	line.text = RichTextMarkup.resolve_dialogue_colors(raw_text, clue_id)

	var label: DialogueLabel
	if line.character == SYSTEM_CHARACTER:
		label = _add_console_line(line)
		await _type_out(label)
	else:
		var is_player: bool = line.character == PLAYER_CHARACTER
		if not is_player:
			await _show_typing_indicator()
		label = _add_bubble(line, is_player)
		await _type_out(label)

	if not clue_id.is_empty():
		var rebuild := func(hovered_id: String) -> void:
			line.text = RichTextMarkup.resolve_dialogue_colors(raw_text, clue_id, hovered_id)
			label.dialogue_line = line
		RichTextMarkup.wire_indice_interactions(label, rebuild)

	_log.append({ "character": line.character, "text": line.text })

	if line.responses.size() > 0:
		_responses_menu.responses = line.responses
		_messages_list.move_child(_responses_menu, _messages_list.get_child_count() - 1)
		_responses_menu.show()
		choice_shown.emit()
		_scroll_to_bottom()
	else:
		await _advance(line.next_id)


func _on_response_selected(response: DialogueResponse) -> void:
	_responses_menu.hide()
	await _advance(response.next_id)


func _on_conversation_finished() -> void:
	SaveManager.record_conversation(_contact.contact_id, _log)
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())
	conversation_finished.emit()


## Symétrique de _on_conversation_finished ci-dessus, pour trigger_help() :
## pas de conversation_finished.emit() ici, une demande d'aide n'est pas une
## "fin de conversation" au sens narratif (pas de révélation de Jean à
## déclencher) — juste un fil qui vient de grandir, à persister comme le reste.
func _on_help_finished() -> void:
	SaveManager.record_conversation(_contact.contact_id, _log)
	SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())


func _show_typing_indicator() -> void:
	var placeholder := DialogueLine.new()
	placeholder.text = "..."

	var bubble: ChatBubble = CHAT_BUBBLE.instantiate()
	_messages_list.add_child(bubble)
	_messages_list.move_child(bubble, _responses_menu.get_index())
	bubble.configure(placeholder, false, _contact.bubble_color)
	_scroll_to_bottom()

	await get_tree().create_timer(TYPING_INDICATOR_SECONDS).timeout
	bubble.queue_free()


func _add_bubble(line: DialogueLine, is_player: bool) -> DialogueLabel:
	var bubble: ChatBubble = CHAT_BUBBLE.instantiate()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN

	_messages_list.add_child(bubble)
	_messages_list.move_child(bubble, _responses_menu.get_index())

	var label := bubble.configure(line, is_player, _contact.bubble_color)
	_scroll_to_bottom()
	return label


## A plain, full-width, no-bubble line — connection status or the
## player-character's own asides, styled like terminal output rather than
## a message exchanged with the contact.
func _add_console_line(line: DialogueLine) -> DialogueLabel:
	var label := DialogueLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.CONSOLE_TEXT)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_SMALL)
	label.dialogue_line = line

	_messages_list.add_child(label)
	_messages_list.move_child(label, _responses_menu.get_index())
	_scroll_to_bottom()
	return label


## Shared by bubbles and console lines: run the typewriter effect while
## tracking _current_label, so a click anywhere can skip whichever is typing.
func _type_out(label: DialogueLabel) -> void:
	_current_label = label
	label.type_out()
	await label.finished_typing
	_current_label = null


## Deux frames, pas une : quand un choix apparaît, ResponsesMenu (un Container
## de l'addon Dialogue Manager) recrée ses boutons et ne finit son propre
## redimensionnement qu'au tri différé du frame suivant — avec une seule
## frame d'attente, max_value était encore lu avant que ce tri n'ait eu lieu,
## et le scroll s'arrêtait juste avant les boutons de réponse.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)
