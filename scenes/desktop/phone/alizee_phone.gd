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


func _ready() -> void:
	_sms_button.pressed.connect(func() -> void: icon_pressed.emit(SECTION_SMS))
	_mail_button.pressed.connect(func() -> void: icon_pressed.emit(SECTION_MAIL))
	_gallery_button.pressed.connect(func() -> void: icon_pressed.emit(SECTION_GALLERY))
	_vault_button.pressed.connect(func() -> void: icon_pressed.emit(SECTION_VAULT))
