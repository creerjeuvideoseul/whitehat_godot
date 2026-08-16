extends Control
class_name WarningDialog
## Boîte de confirmation "destructive" (écraser la partie, quitter le jeu,
## générer le rapport de mission) — même structure que ClueBoardTooltip
## (cadre + halo sur un Control classique, jamais clippé), en vert au lieu du
## jaune, avec un texte d'avertissement + deux boutons (Confirmer/Annuler)
## plutôt qu'un message + Fermer. Remplace ConfirmationDialog partout dans le
## jeu (voir main_menu.gd, options_panel.gd, clue_board_window.gd) :
## ConfirmationDialog hérite de Window/Viewport, qui clippe tout ce qui
## déborde de son propre rect — impossible d'y afficher un halo diffus
## (StyleBoxFlat.shadow_*), contrairement à un Control ordinaire comme
## celui-ci. L'ancien DialogStyle (scenes/ui/dialog_style.gd), qui stylait
## ConfirmationDialog en place, a été supprimé une fois ce remplacement fait
## partout — plus aucun appelant.
##
## Ajoutée en plein écran par l'appelant, se centre elle-même ; hauteur
## dynamique selon le texte (voir _resize_to_content, même recette que
## ClueBoardTooltip._resize_to_content).

const BOX_WIDTH := 1200.0
const BUTTON_FONT_SIZE := Palette.SIZE_BODY
const BUTTON_PADDING := Vector2(28.0, 14.0)

signal confirmed
signal cancelled

@onready var _box: Panel = %Box
@onready var _margin: MarginContainer = %Margin
@onready var _message_label: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	# Bloque les clics vers ce qu'il y a derrière tant que la boîte est
	# affichée (même comportement "exclusif" que l'ancien ConfirmationDialog)
	# — même sur les zones transparentes du Control racine, pas seulement Box.
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_pad_button(_confirm_button, &"PrimaryButton")
	_pad_button(_cancel_button, &"SecondaryButton")


## `message` : texte déjà résolu par l'appelant (peut concaténer plusieurs
## clés ui.csv avec un \n, voir main_menu.gd — même besoin que l'ancien
## ConfirmationDialog.dialog_text). `confirm_text`/`cancel_text` : clés ui.csv
## des boutons.
func set_text(message: String, confirm_text: String, cancel_text: String) -> void:
	_message_label.text = message
	_confirm_button.text = tr(confirm_text)
	_cancel_button.text = tr(cancel_text)


func show_centered() -> void:
	show()
	await _resize_to_content()


## Même recette que ClueBoardTooltip._resize_to_content : la largeur seule est
## fixe (BOX_WIDTH), la hauteur se recalcule à partir de la taille minimale
## réelle du contenu (texte replié + boutons) une fois qu'une frame de layout
## s'est écoulée.
func _resize_to_content() -> void:
	await get_tree().process_frame
	var height: float = _margin.get_combined_minimum_size().y
	_box.offset_top = -height * 0.5
	_box.offset_bottom = height * 0.5


func _on_confirm_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()
	cancelled.emit()


## Même recette que l'ancien DialogStyle._pad_button (supprimé, tous ses
## appelants sont passés à WarningDialog — voir doc de classe) : applique la
## variation de thème demandée puis grossit le padding interne par-dessus.
func _pad_button(button: Button, variation: StringName) -> void:
	button.theme_type_variation = variation
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = BUTTON_PADDING.x
		style.content_margin_right = BUTTON_PADDING.x
		style.content_margin_top = BUTTON_PADDING.y
		style.content_margin_bottom = BUTTON_PADDING.y
		button.add_theme_stylebox_override(state, style)
