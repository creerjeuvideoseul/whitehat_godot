extends Control
class_name GalleryDetail
## Détail d'une publication de la Galerie : photo en grand + commentaires.
## Instancié par GallerySection comme une "copie" de sa fenêtre affichée par-
## dessus (même chrome, taille identique) — voir GallerySection._open_detail().
## Jetable : une nouvelle instance à chaque publication ouverte, libérée à la
## fermeture plutôt que réutilisée (pas d'état à conserver entre deux photos).

signal closed

const AVATAR_SIZE := Vector2(44, 44)
## Seule la hauteur du cadre image est fixe — la largeur suit celle de
## DetailRoot (SIZE_EXPAND_FILL, pleine largeur, pas de bande vide sur les
## côtés). AspectRatioContainer et EXPAND_FIT_WIDTH_PROPORTIONAL calculaient
## eux la hauteur À PARTIR de la largeur, dans un conteneur où cette largeur
## n'est pas encore stabilisée au premier passage de mise en page : d'où le
## débordement de l'image sur le texte suivant vu en test. Une hauteur fixe
## élimine ce problème sans sacrifier la largeur : STRETCH_KEEP_ASPECT_CENTERED
## contient toujours la photo entière dedans, jamais tronquée.
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
	_back_button.pressed.connect(func() -> void: closed.emit())
	_close_button.pressed.connect(func() -> void: closed.emit())


## L'indice éventuel de la publication se débloque à l'ouverture du détail —
## comme un tag [#indice=xxx] de dialogue, voir ClueManager.unlock() — mais
## jamais tant que la publication reste chiffrée et le coffre verrouillé.
func show_post(post: GalleryPost) -> void:
	var locked := post.is_crypted and not PhoneVault.is_unlocked()

	_title_label.text = tr("MAIL_ENCRYPTED_TITLE") if locked else post.title
	_date_label.text = "" if locked else PhoneTime.format_timestamp(post.timestamp)

	if not locked and not post.indice.is_empty():
		ClueManager.unlock(post.indice)

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
	rect.custom_minimum_size = Vector2(0, DETAIL_IMAGE_HEIGHT)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not post.picture_path.is_empty() and ResourceLoader.exists(post.picture_path):
		rect.texture = load(post.picture_path)
	return rect


func _build_description(post: GalleryPost) -> Control:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	var resolved := RichTextMarkup.resolve_indice_tags(post.description)
	label.text = RichTextMarkup.html_to_bbcode(resolved)
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

	var message_label := Label.new()
	message_label.text = comment.message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
	message_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
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
