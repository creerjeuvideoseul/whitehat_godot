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
## pensées), elle se contente de fournir le texte déjà traduit ainsi que sa
## clé ui.csv (voir _resolve_wrong_password_hint_key) — desktop.gd s'en sert
## pour journaliser la pensée dans SaveManager.record_thought() sans dépendre
## du texte brut, robuste à un changement de langue en cours de partie.
signal thought_requested(text: String, translation_key: String)

const PADLOCK_CLOSED := preload("res://assets/UI/padlock.png")
const PADLOCK_OPEN := preload("res://assets/UI/open-padlock.png")

const CORRECT_PASSWORD := "lasthorizon11"

## Pensées affichées dans l'ordre à chaque mot de passe incorrect — de plus en
## plus précises pour aider un joueur qui bloque, puis en boucle une fois la
## liste épuisée plutôt que de se taire après la dernière (voir
## _next_wrong_attempt_hint).
const WRONG_ATTEMPT_HINT_KEYS := [
	"VAULT_HINT_ATTEMPT_1",
	"VAULT_HINT_ATTEMPT_2",
	"VAULT_HINT_ATTEMPT_3",
	"VAULT_HINT_ATTEMPT_4",
	"VAULT_HINT_ATTEMPT_5",
]

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
## Nombre de mots de passe incorrects saisis depuis l'ouverture du coffre —
## fait avancer dans WRONG_ATTEMPT_HINT_KEYS (voir _next_wrong_attempt_hint).
## Remis à zéro à chaque nouvelle instance (on ressort du téléphone puis on y
## revient) : pas de persistance voulue au-delà d'une session d'affichage.
var _wrong_attempt_count: int = 0


func _ready() -> void:
	_invalid_chars_regex.compile(INVALID_CHARS_PATTERN)
	_close_button.pressed.connect(func() -> void:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		close_requested.emit()
	)
	_password_edit.text_changed.connect(_on_password_text_changed)
	_password_edit.text_submitted.connect(func(_text: String) -> void: _on_validate_pressed())
	_validate_button.pressed.connect(_on_validate_pressed)

	if PhoneVault.is_unlocked():
		_show_success(false)
	else:
		_padlock_icon.texture = PADLOCK_CLOSED
		# Le joueur doit pouvoir taper le mot de passe dès l'ouverture du
		# coffre, sans avoir à cliquer d'abord dans le champ.
		_password_edit.grab_focus()


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
	var hint_key := _resolve_wrong_password_hint_key(normalized)
	thought_requested.emit(tr(hint_key), hint_key)


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


## Pistes spécifiques à CE que le joueur vient de taper (une saisie proche
## d'un mot de passe connu mais erroné) — prioritaires sur la progression
## générale par tentative (voir _next_wrong_attempt_hint_key), qui ne sert de
## repli que si aucune de ces exceptions ne correspond. `normalized` est déjà
## en minuscules et débarrassé de tout caractère hors [a-z0-9] (voir
## _normalize), donc "EliteShot$83$" et "EliteShot83" déclenchent la même
## pensée. Retourne la clé ui.csv (pas le texte traduit) — voir
## _on_validate_pressed, qui l'utilise pour journaliser la pensée dans
## SaveManager.record_thought() sans dépendre du texte déjà résolu.
##
## VAULT_HINT_ELEVEN volontairement en dernier parmi ces pistes spécifiques
## (juste avant le repli générique) : "contains('11')" est un test large qui
## peut correspondre à une saisie visant surtout autre chose (ex. une date
## comme "0811") — retour joueur, ce message apparaissait trop souvent et
## passait avant des pistes plus pertinentes. Date reconnue à tout nombre
## entier, pas seulement 6 chiffres : un "0811" (jour+mois) doit lui aussi
## être lu comme une tentative de date, pas comme visant le chiffre 11.
func _resolve_wrong_password_hint_key(normalized: String) -> String:
	if normalized.is_valid_int():
		return "VAULT_HINT_DATE"
	if normalized == "peaceandlove" or normalized == "alizeemarek":
		return "VAULT_HINT_SOCIAL"
	if normalized == "eliteshot83":
		return "VAULT_HINT_ELITESHOT"
	if normalized == "bugsy":
		return "VAULT_HINT_BUGSY"
	if normalized.begins_with("lasthorizon"):
		return "VAULT_HINT_LASTHORIZON"
	if normalized.contains("11"):
		return "VAULT_HINT_ELEVEN"
	return _next_wrong_attempt_hint_key()


## Une pensée différente à chaque tentative incorrecte "générique" (voir
## WRONG_ATTEMPT_HINT_KEYS et _resolve_wrong_password_hint_key ci-dessus), de
## plus en plus précise pour aider un joueur qui reste bloqué — puis en boucle
## une fois la liste épuisée, plutôt que de ne plus rien dire.
func _next_wrong_attempt_hint_key() -> String:
	var key: String = WRONG_ATTEMPT_HINT_KEYS[_wrong_attempt_count % WRONG_ATTEMPT_HINT_KEYS.size()]
	_wrong_attempt_count += 1
	return key


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
