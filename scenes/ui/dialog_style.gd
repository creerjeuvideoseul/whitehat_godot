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
## connexions de signal...) — ne touche que l'apparence. Les boutons OK/Annuler
## reprennent les Theme Type Variations du reste du jeu (voir main_theme.tres)
## plutôt qu'un style dupliqué à la main — PrimaryButton pour "Confirmer",
## et SecondaryButton (même police/taille/padding, fond+bordure gris, texte
## noir) pour "Retour", pour bien le distinguer visuellement comme l'option
## non destructive.
static func style_warning_dialog(dialog: ConfirmationDialog) -> void:
	dialog.get_label().add_theme_color_override("font_color", Palette.TEXT_DANGER)
	dialog.get_label().add_theme_font_size_override("font_size", Palette.SIZE_LARGE)
	_pad_button(dialog.get_ok_button(), &"PrimaryButton")
	_pad_button(dialog.get_cancel_button(), &"SecondaryButton")


## Applique la variation de thème demandée puis grossit le padding interne
## par-dessus (les variations du thème n'ont qu'un padding standard, pas
## celui, plus généreux, voulu spécifiquement pour ces dialogs).
static func _pad_button(button: Button, variation: StringName) -> void:
	button.theme_type_variation = variation
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = BUTTON_PADDING.x
		style.content_margin_right = BUTTON_PADDING.x
		style.content_margin_top = BUTTON_PADDING.y
		style.content_margin_bottom = BUTTON_PADDING.y
		button.add_theme_stylebox_override(state, style)
