class_name DialogStyle
## Point unique de mise en forme des ConfirmationDialog d'avertissement du jeu
## (écraser la partie, quitter la partie, et les prochaines à venir) — évite
## de dupliquer la même taille de police et le même padding de boutons à
## chaque nouvel appelant. Taille de référence : Palette.SIZE_LARGE, celle du
## DialogueLabel de l'intro (voir Palette.gd).

## Taille des boutons OK/Annuler — celle déjà utilisée pour PrimaryButton
## ailleurs dans le jeu (voir main_theme.tres), pour rester cohérent avec le
## reste des boutons plutôt qu'avec le texte d'avertissement (SIZE_LARGE).
const BUTTON_FONT_SIZE := Palette.SIZE_BODY
const BUTTON_PADDING := Vector2(28.0, 14.0)


## À appeler une fois la dialog par ailleurs configurée (titre, texte,
## connexions de signal...) — ne touche que l'apparence.
static func style_warning_dialog(dialog: ConfirmationDialog) -> void:
	dialog.get_label().add_theme_color_override("font_color", Palette.TEXT_DANGER)
	dialog.get_label().add_theme_font_size_override("font_size", Palette.SIZE_LARGE)
	_pad_button(dialog.get_ok_button())
	_pad_button(dialog.get_cancel_button())


## Grossit le padding interne du bouton en dupliquant son style actuel
## (garde son apparence — bordure, couleurs — telle quelle) plutôt qu'en
## forçant une taille minimale, qui laissait un texte minuscule flotter au
## milieu d'une grosse boîte au lieu d'un vrai padding autour du texte.
static func _pad_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = BUTTON_PADDING.x
		style.content_margin_right = BUTTON_PADDING.x
		style.content_margin_top = BUTTON_PADDING.y
		style.content_margin_bottom = BUTTON_PADDING.y
		button.add_theme_stylebox_override(state, style)
