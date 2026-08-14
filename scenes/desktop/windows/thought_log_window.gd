extends Control
class_name ThoughtLogWindow
## Fenêtre "Analyse Rétrospective" : historique de toutes les pensées du
## joueur affichées depuis le début de la partie (voir player_thought.gd et
## SaveManager.record_thought), classées de la plus ancienne à la plus
## récente. Même chrome (fond/cadre vert, barre de titre) que ClueBoardWindow —
## réutilisée en une seule instance par desktop.gd (voir
## _on_thought_log_button_pressed), jamais fermée/détruite, juste cachée (voir
## _on_close_pressed).
##
## Chaque entrée est affichée comme un message de ChatWindow (voir ChatBubble)
## teinté "pensée du joueur" (Palette.BUBBLE_PLAYER), alignée à gauche comme
## une entrée de journal plutôt qu'à droite comme une réponse à un
## interlocuteur — avec la date/heure du jeu juste en dessous, en gris, même
## recette que SmsSection.

const CHAT_BUBBLE := preload("res://scenes/desktop/windows/chat_bubble.tscn")

@onready var _close_button: Button = %CloseButton
@onready var _messages_list: VBoxContainer = %MessagesList


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	refresh()


## Reconstruit entièrement la liste à partir de SaveManager.get_thought_log() —
## appelé à chaque ouverture (voir desktop.gd::_on_thought_log_button_pressed)
## pour inclure les pensées ajoutées depuis la dernière fois.
func refresh() -> void:
	for child in _messages_list.get_children():
		child.queue_free()

	var thought_log := SaveManager.get_thought_log()
	if thought_log.is_empty():
		_messages_list.add_child(_build_empty_label())
		return

	for entry: Dictionary in thought_log:
		_build_entry(entry)


func _build_empty_label() -> Label:
	var label := Label.new()
	label.text = tr("THOUGHT_LOG_EMPTY")
	label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	return label


## Texte re-résolu via tr(key) si une clé de traduction existait à
## l'enregistrement (voir SaveManager.record_thought) — pour rester juste si
## le joueur change de langue en cours de partie. Repli sur le texte brut déjà
## enregistré sinon (pensées sans clé ui.csv, ex. celles du mail — voir
## mail_section.gd).
##
## `column` doit rejoindre _messages_list (déjà dans l'arbre) AVANT que
## `bubble` n'y soit ajouté et configuré — ChatBubble.configure() s'appuie sur
## %DialogueLabel, résolu par @onready seulement une fois le nœud réellement
## entré dans l'arbre (voir ConversationView._add_bubble, même contrainte
## d'ordre). Construire toute la colonne à part puis l'ajouter d'un bloc, comme
## la première version le faisait, laissait ChatBubble configuré "hors arbre".
func _build_entry(entry: Dictionary) -> void:
	var key: String = entry.get("key", "")
	var text: String = tr(key) if not key.is_empty() else str(entry.get("text", ""))

	var line := DialogueLine.new()
	line.text = text

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 4)
	_messages_list.add_child(column)

	var bubble: ChatBubble = CHAT_BUBBLE.instantiate()
	column.add_child(bubble)
	bubble.configure(line, true)

	var timestamp := Label.new()
	var iso_timestamp := Time.get_datetime_string_from_unix_time(int(entry.get("game_unix_time", 0)))
	timestamp.text = PhoneTime.format_timestamp(iso_timestamp)
	timestamp.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	timestamp.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	column.add_child(timestamp)


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
