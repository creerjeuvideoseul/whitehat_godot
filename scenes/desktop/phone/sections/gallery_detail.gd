extends Control
class_name GalleryDetail
## Détail d'une publication de la Galerie : photo en grand + commentaires.
## Instancié par GallerySection comme une "copie" de sa fenêtre affichée par-
## dessus (même chrome, taille identique) — voir GallerySection._open_detail().
## Jetable : une nouvelle instance à chaque publication ouverte, libérée à la
## fermeture plutôt que réutilisée (pas d'état à conserver entre deux photos).

signal closed

const AVATAR_SIZE := Vector2(44, 44)
## Hauteur MAXIMALE du cadre image (voir _fit_image_height) — la largeur suit
## toujours celle de DetailRoot (SIZE_EXPAND_FILL, pleine largeur, pas de
## bande vide sur les côtés). Une ancienne version imposait cette hauteur en
## dur pour toutes les photos : correct pour les photos portrait, mais un
## grand vide au-dessus/en dessous des photos au format paysage (largeur du
## cadre grande, hauteur réelle après mise à l'échelle bien inférieure à 900 —
## voir échange avec l'utilisateur). _fit_image_height calcule maintenant la
## vraie hauteur d'après le ratio de la photo, cette constante ne servant plus
## que de plafond pour les formats portrait très hauts.
const DETAIL_IMAGE_HEIGHT := 900
## DetailRoot n'a plus d'espacement uniforme (theme_override_constants/
## separation = 0 dans la scène) : ce gap est ajouté à la main entre les
## éléments qui en ont besoin, en le sautant volontairement avant l'image
## (premier élément de DetailRoot depuis que la date est passée dans la barre
## de titre) pour qu'elle colle directement sous celle-ci.
const GAP_SIZE := 16

@onready var _title_label: Label = %TitleLabel
@onready var _date_label: Label = %DateLabel
@onready var _back_button: Button = %BackButton
@onready var _close_button: Button = %CloseButton
@onready var _detail_root: VBoxContainer = %DetailRoot


func _ready() -> void:
	# RETOUR (à gauche) fait exactement la même chose que la croix (à droite) —
	# deux façons d'accéder à la même action, pas deux comportements différents.
	_back_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		closed.emit()
	)
	_close_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		closed.emit()
	)


func show_post(post: GalleryPost) -> void:
	var locked := post.is_crypted and not PhoneVault.is_unlocked()

	_title_label.text = tr("MAIL_ENCRYPTED_TITLE") if locked else post.title
	_date_label.text = "" if locked else PhoneTime.format_timestamp(post.timestamp)

	for child in _detail_root.get_children():
		child.queue_free()

	if locked:
		_detail_root.add_child(_build_locked_placeholder())
		return

	_detail_root.add_child(_build_image(post))
	if not post.description.is_empty():
		_add_gap()
		_detail_root.add_child(_build_description(post))
	for comment: GalleryComment in post.comments:
		_add_gap()
		_detail_root.add_child(_build_comment_row(comment))


func _add_gap() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, GAP_SIZE)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_root.add_child(spacer)


func _build_locked_placeholder() -> Control:
	var label := Label.new()
	label.text = tr("VAULT_ENCRYPTED_PLACEHOLDER")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	label.add_theme_font_size_override("font_size", Palette.SIZE_BODY)
	return label


func _build_image(post: GalleryPost) -> Control:
	var rect := TextureRect.new()
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not post.picture_path.is_empty() and ResourceLoader.exists(post.picture_path):
		rect.texture = load(post.picture_path)
		_fit_image_height(rect)
	return rect


## Fixe la hauteur du cadre d'après le ratio réel de la photo une fois que la
## largeur de DetailRoot (donc de ce TextureRect) s'est stabilisée — deux
## frames d'attente, même recette que _resize_to_content (ClueBoardTooltip/
## ClueSpotlight/ClueFusion). Plafonnée à DETAIL_IMAGE_HEIGHT pour les formats
## portrait très hauts ; les formats paysage obtiennent une hauteur bien plus
## faible, sans grand vide au-dessus/en dessous.
func _fit_image_height(rect: TextureRect) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(rect):
		return
	var texture_size := rect.texture.get_size()
	var fitted_height := rect.size.x * (texture_size.y / texture_size.x)
	rect.custom_minimum_size.y = minf(fitted_height, DETAIL_IMAGE_HEIGHT)


func _build_description(post: GalleryPost) -> Control:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	var rebuild := func(hovered_id: String) -> void:
		label.text = RichTextMarkup.html_to_bbcode(RichTextMarkup.resolve_indice_tags(post.description, Palette.TEXT_HIGHLIGHT, Palette.TEXT_CLUE_CLICKED, hovered_id))
	rebuild.call("")
	if post.description.contains("<indice id="):
		RichTextMarkup.wire_indice_interactions(label, rebuild)
	return label


func _build_comment_row(comment: GalleryComment) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_child(_build_avatar(comment))

	var username_label := Label.new()
	username_label.text = comment.username
	username_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	username_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	username_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(username_label)
	box.add_child(header)

	## RichTextLabel, pas Label : les commentaires peuvent contenir des balises
	## <color=...> (voir alizee_galerie.json) qui, sur un Label simple,
	## s'affichaient telles quelles au lieu d'être interprétées.
	var message_label := RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.selection_enabled = true
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	# SIZE_BODY, pas SIZE_SMALL : même taille que la description au-dessus
	# (_build_description) et que le texte des bulles de conversation ailleurs
	# dans le projet (chat_bubble.tscn) — SIZE_SMALL est réservé aux éléments
	# secondaires (username_label ci-dessus, lignes système), pas au contenu
	# du message lui-même (retour joueur : les commentaires semblaient plus
	# petits que la description).
	message_label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	var rebuild := func(hovered_id: String) -> void:
		message_label.text = RichTextMarkup.html_to_bbcode(RichTextMarkup.resolve_indice_tags(comment.message, Palette.TEXT_HIGHLIGHT, Palette.TEXT_CLUE_CLICKED, hovered_id))
	rebuild.call("")
	if comment.message.contains("<indice id="):
		RichTextMarkup.wire_indice_interactions(message_label, rebuild)
	box.add_child(message_label)

	return box


func _build_avatar(comment: GalleryComment) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(2)
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(int(AVATAR_SIZE.x / 2.0))
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = AVATAR_SIZE

	var rect := TextureRect.new()
	rect.custom_minimum_size = AVATAR_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not comment.avatar_path.is_empty() and ResourceLoader.exists(comment.avatar_path):
		rect.texture = load(comment.avatar_path)
	frame.add_child(rect)
	return frame
