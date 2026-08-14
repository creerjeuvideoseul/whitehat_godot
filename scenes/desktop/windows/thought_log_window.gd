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
## Chaque entrée prend toute la largeur disponible (retour utilisateur : pas
## question de rester étroit comme les bulles SMS de la colonne de gauche) —
## un style "carte" dédié plutôt que la vraie ChatBubble de ChatWindow, qui
## elle est justement pensée pour se réduire au texte. Teinte "pensée du
## joueur" (Palette.BUBBLE_PLAYER) conservée, avec la date/heure du jeu juste
## en dessous, en gris, même recette que SmsSection.

## Même padding/arrondi que ChatBubble, pour rester dans le même langage
## visuel malgré le style différent (voir chat_bubble.gd::configure).
const CARD_CORNER_RADIUS := 14
const CARD_MARGIN_H := 18
const CARD_MARGIN_V := 12

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
## mail_section.gd). Texte brut simple (jamais de BBCode côté données, voir
## MailEntry.player_think) — un Label suffit, pas besoin d'un RichTextLabel.
func _build_entry(entry: Dictionary) -> void:
	var key: String = entry.get("key", "")
	var text: String = tr(key) if not key.is_empty() else str(entry.get("text", ""))

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	_messages_list.add_child(column)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BUBBLE_PLAYER
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.content_margin_left = CARD_MARGIN_H
	style.content_margin_right = CARD_MARGIN_H
	style.content_margin_top = CARD_MARGIN_V
	style.content_margin_bottom = CARD_MARGIN_V
	card.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	card.add_child(label)
	column.add_child(card)

	var timestamp := Label.new()
	var iso_timestamp := Time.get_datetime_string_from_unix_time(int(entry.get("game_unix_time", 0)))
	timestamp.text = PhoneTime.format_timestamp(iso_timestamp)
	timestamp.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	timestamp.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	column.add_child(timestamp)


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
