extends Control
class_name AttachmentViewer
## Visionneuse plein cadre pour une image jointe (ex: pièce jointe d'un mail,
## voir MailSection._open_attachment_viewer) — même chrome que GalleryDetail
## (fond/bordure vive, barre de titre avec bouton "Retour"), en plus simple
## puisqu'il n'y a ni date ni commentaires à afficher, juste l'image en grand.
## Jetable comme GalleryDetail : une nouvelle instance à chaque ouverture,
## libérée à la fermeture.

signal closed

## Même hauteur que GalleryDetail.DETAIL_IMAGE_HEIGHT, pour qu'une image
## ouverte en grand depuis n'importe quel écran ait toujours la même taille.
const IMAGE_HEIGHT := 900
## Petit effet de zoom/fondu à l'ouverture (voir _ready).
const OPEN_ANIM_SECONDS := 0.25
const OPEN_ANIM_START_SCALE := 0.92

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _close_button: Button = %CloseButton
@onready var _image_rect: TextureRect = %ImageRect


func _ready() -> void:
	_image_rect.custom_minimum_size = Vector2(0, IMAGE_HEIGHT)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# RETOUR (à gauche) fait exactement la même chose que la croix (à droite) —
	# même convention que GalleryDetail : deux façons d'accéder à la même action.
	_back_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		closed.emit()
	)
	_close_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		closed.emit()
	)
	_play_open_animation()


## `title_text` déjà traduit par l'appelant, comme partout ailleurs dans le
## projet (voir PlayerThought.text).
func show_image(image_path: String, title_text: String) -> void:
	_title_label.text = title_text
	if ResourceLoader.exists(image_path):
		_image_rect.texture = load(image_path)


## Léger zoom + fondu d'entrée, plutôt qu'une apparition brutale — pas de son
## dédié ici, le clic sur la vignette (voir MailSection._on_attachment_gui_input)
## a déjà joué le même SfxPlayer.UI_CLICK_SFX utilisé pour tous les éléments
## cliquables du jeu.
func _play_open_animation() -> void:
	modulate.a = 0.0
	scale = Vector2(OPEN_ANIM_START_SCALE, OPEN_ANIM_START_SCALE)
	await get_tree().process_frame
	pivot_offset = size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, OPEN_ANIM_SECONDS)
	tween.tween_property(self, "scale", Vector2.ONE, OPEN_ANIM_SECONDS)
