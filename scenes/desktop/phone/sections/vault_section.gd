extends Control
class_name VaultSection
## Section "Coffre-fort" du téléphone d'Alizée : puzzle de mot de passe qui
## débloque StoryVars.phone_vault_unlocked (voir PhoneVault) — déjà lu par
## MailSection/SmsSection/GallerySection partout où du contenu crypté existe,
## donc poser ce flag à true suffit à tout révéler, sans code supplémentaire.
##
## Pas de barre de titre déplaçable/réductible : comme MailSection/GallerySection,
## ce n'est pas une fenêtre du bureau mais le contenu d'un écran du téléphone.

signal close_requested
## Émis pour demander l'affichage d'une "pensée du joueur" (voir player_thought.gd) —
## cette scène ne connaît pas WindowLayer (c'est desktop.gd qui y ajoute les
## pensées), elle se contente de fournir le texte déjà traduit.
signal thought_requested(text: String)

const PADLOCK_CLOSED := preload("res://assets/UI/padlock.png")
const PADLOCK_OPEN := preload("res://assets/UI/open-padlock.png")

const CORRECT_PASSWORD := "lasthorizon11"

## Caractères autorisés à la saisie : alphanumérique + les symboles utilisés
## dans les mots de passe à deviner (dates avec / ou -, EliteShot$83$, Alizee&Marek).
const INVALID_CHARS_PATTERN := "[^A-Za-z0-9/$&-]"

## Repli accents si un copier-coller en laisse passer malgré le filtre de
## saisie — la comparaison doit rester insensible aux accents comme demandé.
const _ACCENT_MAP := {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "ì": "i", "í": "i",
	"ô": "o", "ö": "o", "ò": "o", "ó": "o", "õ": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c",
}

@onready var _close_button: Button = %CloseButton
@onready var _padlock_icon: TextureRect = %PadlockIcon
@onready var _password_edit: LineEdit = %PasswordEdit
@onready var _validate_button: Button = %ValidateButton
@onready var _status_label: Label = %StatusLabel

var _invalid_chars_regex := RegEx.new()


func _ready() -> void:
	_invalid_chars_regex.compile(INVALID_CHARS_PATTERN)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_password_edit.text_changed.connect(_on_password_text_changed)
	_password_edit.text_submitted.connect(func(_text: String) -> void: _on_validate_pressed())
	_validate_button.pressed.connect(_on_validate_pressed)

	if PhoneVault.is_unlocked():
		_show_success(false)
	else:
		_padlock_icon.texture = PADLOCK_CLOSED


## Même filtrage en direct que login.gd (PseudoEdit) : on retire les
## caractères interdits au fil de la frappe plutôt qu'à la validation, pour
## qu'un copier-coller ou une touche interdite ne s'affiche jamais.
func _on_password_text_changed(new_text: String) -> void:
	var filtered := _invalid_chars_regex.sub(new_text, "", true)
	if filtered != new_text:
		var caret := _password_edit.caret_column
		_password_edit.text = filtered
		_password_edit.caret_column = clampi(caret - 1, 0, filtered.length())


func _on_validate_pressed() -> void:
	var raw_input := _password_edit.text
	if raw_input.is_empty():
		return

	var normalized := _normalize(raw_input)
	if normalized == CORRECT_PASSWORD:
		_show_success(true)
		return

	SfxPlayer.play(SfxPlayer.ACCESS_DENIED_SFX)
	_status_label.add_theme_color_override("font_color", Palette.TEXT_DANGER)
	_status_label.text = tr("VAULT_WRONG_PASSWORD")
	thought_requested.emit(_resolve_hint(normalized))


## `announce`: vrai juste après une validation réussie (déclenche la
## sauvegarde) ; faux à la réouverture d'un coffre déjà déverrouillé lors
## d'une session précédente (rien à re-signaler, juste afficher l'état final).
func _show_success(announce: bool) -> void:
	StoryVars.phone_vault_unlocked = true
	_padlock_icon.texture = PADLOCK_OPEN
	_password_edit.visible = false
	_validate_button.visible = false
	_status_label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	_status_label.text = tr("VAULT_SUCCESS_MESSAGE")

	if announce:
		SfxPlayer.play(SfxPlayer.MAJOR_REVEAL_SFX)
		# Même précédent que la fin du dump de Jean (voir desktop.gd) : un
		# déverrouillage de coffre est un vrai jalon narratif, à ne pas perdre
		# si le joueur quitte juste après.
		SaveManager.save_checkpoint(SaveManager.get_checkpoint_scene())


## Ordre de vérification = l'ordre du plus spécifique (une piste nommée) au
## plus générique (repli), tel que conçu. `normalized` est déjà en minuscules
## et débarrassé de tout caractère hors [a-z0-9] (voir _normalize) — les
## mots de passe de référence ci-dessous sont comparés sous la même forme,
## donc "EliteShot$83$" et "EliteShot83" déclenchent la même pensée.
func _resolve_hint(normalized: String) -> String:
	if normalized.is_valid_int() and normalized.length() == 6:
		return tr("VAULT_HINT_DATE")
	if normalized == "peaceandlove" or normalized == "alizeemarek":
		return tr("VAULT_HINT_SOCIAL")
	if normalized == "eliteshot83":
		return tr("VAULT_HINT_ELITESHOT")
	if normalized == "bugsy":
		return tr("VAULT_HINT_BUGSY")
	if normalized.contains("11"):
		return tr("VAULT_HINT_ELEVEN")
	if normalized.begins_with("lasthorizon"):
		return tr("VAULT_HINT_LASTHORIZON")
	return tr("VAULT_HINT_GENERIC")


## Minuscules + accents repliés + tout caractère hors [a-z0-9] retiré — "la
## chaîne la plus simple à vérifier" (espaces, /, -, $, & compris), pour que
## la casse, les séparateurs de date ou les symboles ne changent jamais le résultat.
func _normalize(text: String) -> String:
	var lowered := text.to_lower()
	var folded := ""
	for i in lowered.length():
		var ch := lowered[i]
		folded += _ACCENT_MAP.get(ch, ch)
	var result := ""
	for i in folded.length():
		var ch := folded[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			result += ch
	return result
