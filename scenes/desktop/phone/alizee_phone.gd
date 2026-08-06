extends Control
class_name AlizeePhone
## Téléphone d'Alizée : grille d'icônes affichée en permanence sur la gauche
## du bureau une fois le dump de Jean terminé (voir desktop.gd). Ce script ne
## connaît que ses propres icônes — c'est desktop.gd qui décide quelle scène
## de contenu afficher à droite pour chaque section, ce téléphone se contente
## de signaler laquelle a été choisie (Single Responsibility).

## Émis avec l'id de la section demandée ("sms", "mail", "gallery", "vault").
signal icon_pressed(section_id: String)

const SECTION_SMS := "sms"
const SECTION_MAIL := "mail"
const SECTION_GALLERY := "gallery"
const SECTION_VAULT := "vault"

@onready var _sms_button: Button = %SmsButton
@onready var _mail_button: Button = %MailButton
@onready var _gallery_button: Button = %GalleryButton
@onready var _vault_button: Button = %VaultButton

## Les PNG d'icônes sont blancs — un self_modulate vert suffit à teindre
## celle de la section ouverte, pas besoin d'une seconde image par icône.
var _buttons_by_section: Dictionary = {}


func _ready() -> void:
	_buttons_by_section = {
		SECTION_SMS: _sms_button,
		SECTION_MAIL: _mail_button,
		SECTION_GALLERY: _gallery_button,
		SECTION_VAULT: _vault_button,
	}
	_sms_button.pressed.connect(func() -> void: _activate(SECTION_SMS))
	_mail_button.pressed.connect(func() -> void: _activate(SECTION_MAIL))
	_gallery_button.pressed.connect(func() -> void: _activate(SECTION_GALLERY))
	_vault_button.pressed.connect(func() -> void: _activate(SECTION_VAULT))


func _activate(section_id: String) -> void:
	clear_active_icon()
	_buttons_by_section[section_id].self_modulate = Palette.BORDER_ACCENT
	icon_pressed.emit(section_id)


## Appelé par desktop.gd quand la section ouverte se ferme (bouton X de
## MailSection/SmsSection/...) — remet toutes les icônes à leur blanc d'origine.
func clear_active_icon() -> void:
	for button: Button in _buttons_by_section.values():
		button.self_modulate = Color.WHITE
