extends Control
class_name GallerySection
## Section "Galerie" du téléphone d'Alizée : grille de vignettes (façon galerie
## photo mobile), cliquer sur une vignette ouvre le détail de la publication en
## superposition. Générique par conception, comme MailSection/SmsSection —
## seul `data_path` est spécifique à Alizée, une mission 2+ n'aura qu'à
## dupliquer cette scène et changer ce champ dans l'inspecteur.
##
## Pas de barre de titre déplaçable/réductible : ce n'est pas une fenêtre du
## bureau mais le contenu d'un écran du téléphone (voir MailSection pour
## l'explication complète du bouton X / close_requested).

signal close_requested

const PADLOCK_CLOSED := preload("res://assets/UI/padlock.png")
const HEART_ICON := preload("res://assets/UI/gallery_heart.svg")
const COMMENT_ICON := preload("res://assets/UI/gallery_comment.svg")
const GALLERY_DETAIL := preload("res://scenes/desktop/phone/sections/gallery_detail.tscn")

## Largeur fixe d'une vignette ; hauteur d'image relevée de 90px par rapport
## au ratio 16/9 strict (retour utilisateur : trop fine). L'espace d'info sous
## l'image n'a plus de hauteur imposée — il s'ajuste à son propre contenu
## (retour utilisateur : trop de vide sous le titre avec une hauteur fixe).
const THUMB_WIDTH := 250
const THUMB_IMAGE_HEIGHT := 231
const ICON_SIZE := Vector2(20, 20)

## Fichier JSON de la galerie affichée — voir GalleryDatabase. Le seul champ à
## changer pour réutiliser cette scène sur un autre personnage/mission.
@export var data_path: String = "res://data/alizee_galerie.json"

@onready var _close_button: Button = %CloseButton
@onready var _thumb_grid: HFlowContainer = %ThumbGrid

var _database: GalleryDatabase


func _ready() -> void:
	_database = GalleryDatabase.new(data_path)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child in _thumb_grid.get_children():
		child.queue_free()
	for post: GalleryPost in _database.get_posts():
		_thumb_grid.add_child(_build_thumbnail(post))


func _build_thumbnail(post: GalleryPost) -> Control:
	var locked := post.is_crypted and not PhoneVault.is_unlocked()

	var cell := PanelContainer.new()
	# Hauteur plancher = image seule ; le bandeau d'info en dessous s'ajoute par
	# lui-même à la hauteur réelle de la colonne (voir _build_thumbnail_info).
	cell.custom_minimum_size = Vector2(THUMB_WIDTH, THUMB_IMAGE_HEIGHT)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cell.gui_input.connect(_on_thumbnail_gui_input.bind(post))

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	column.add_child(_build_thumbnail_image(post, locked))
	column.add_child(_build_thumbnail_info(post, locked))
	cell.add_child(column)

	# Bordure de survol en calque séparé, ajouté APRÈS column pour se dessiner
	# par-dessus : la vignette (fond blanc de l'image, fond sombre du bandeau
	# d'info) est opaque et couvre toute la cellule sans marge, donc une
	# bordure posée sur le panel de `cell` lui-même serait peinte EN DESSOUS et
	# quasi entièrement recouverte (c'est ce qu'on voyait : un mince filet).
	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_hover_border(border, false)
	cell.add_child(border)

	cell.mouse_entered.connect(func() -> void: _style_hover_border(border, true))
	cell.mouse_exited.connect(func() -> void: _style_hover_border(border, false))

	return cell


## Simple StyleBoxFlat, pas de shader : suffisant pour un effet de
## surbrillance et déjà le mécanisme utilisé partout ailleurs dans le projet
## (avatars, ligne sélectionnée de Mail/SMS) — pas besoin d'introduire un
## nouvel outil pour ça.
func _style_hover_border(border: Panel, is_hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(5 if is_hovered else 0)
	style.border_color = Palette.TEXT_ACCENT
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	border.add_theme_stylebox_override("panel", style)


## L'image "colle les bords" de son cadre blanc (fond blanc demandé,
## contrairement au reste du chrome sombre de l'appli) — recadrée si besoin
## (STRETCH_KEEP_ASPECT_COVERED) plutôt que réduite avec des bandes vides.
## Publication cryptée et coffre pas encore débloqué : cadenas centré à la
## place de la vraie photo, même logique que Mail/SMS.
func _build_thumbnail_image(post: GalleryPost, locked: bool) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Fond blanc uniquement pour une vraie photo (demandé explicitement) — une
	# publication verrouillée garde le fond sombre habituel de l'appli, comme
	# les avatars cadenas de Mail/SMS (jamais de cadenas sur fond blanc).
	style.bg_color = Color(0, 0, 0, 0) if locked else Color.WHITE
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(THUMB_WIDTH, THUMB_IMAGE_HEIGHT)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if locked:
		rect.texture = PADLOCK_CLOSED
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif not post.picture_path.is_empty() and ResourceLoader.exists(post.picture_path):
		rect.texture = load(post.picture_path)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(rect)
	return frame


func _build_thumbnail_info(post: GalleryPost, locked: bool) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.WINDOW_HEADER_BG
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(THUMB_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = tr("MAIL_ENCRYPTED_TITLE") if locked else post.title
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	title_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	box.add_child(title_label)

	if not locked:
		box.add_child(_build_counters_row(post))

	panel.add_child(box)
	return panel


## Le cœur reste sans mot à côté (juste le nombre) — l'icône suffit à faire
## comprendre qu'il s'agit de "j'aime" ; le nombre de commentaires garde un
## mot, moins évident à deviner de la seule icône.
func _build_counters_row(post: GalleryPost) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	row.add_child(_build_counter(HEART_ICON, str(post.nb_like)))
	row.add_child(_build_counter(COMMENT_ICON, tr("GALLERY_COMMENT_COUNT") % post.comments.size()))
	return row


func _build_counter(icon: Texture2D, label_text: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)

	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = ICON_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text
	label.add_theme_color_override("font_color", Palette.CONSOLE_TEXT)
	label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	hbox.add_child(label)

	return hbox


func _on_thumbnail_gui_input(event: InputEvent, post: GalleryPost) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_open_detail(post)


## Le détail est une "copie" de cette fenêtre (même taille/chrome) affichée
## par-dessus : une instance jetable, libérée à la fermeture plutôt que
## cachée/réutilisée, la grille en dessous restant intacte (scroll compris).
func _open_detail(post: GalleryPost) -> void:
	var detail: GalleryDetail = GALLERY_DETAIL.instantiate()
	detail.closed.connect(func() -> void: detail.queue_free())
	add_child(detail)
	detail.show_post(post)
