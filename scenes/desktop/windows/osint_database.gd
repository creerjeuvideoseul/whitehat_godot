extends RefCounted
class_name OsintDatabase
## Charge data/osint_characters.json (une fiche par personnage, en fr ET en —
## voir le fichier lui-même) et sait retrouver un personnage par recherche
## floue de nom/prénom. Contrairement à ClueManager (CSV, clé -> texte via
## ui.csv), ces fiches sont des enregistrements structurés à contenu libre :
## chaque champ du JSON sert à la fois de clé ET de libellé affiché, déjà
## dans la bonne langue — voir OsintWindow pour l'affichage.

const DATA_PATH := "res://data/osint_characters.json"
const DEFAULT_LOCALE := "fr"

## Champs à traitement spécial (bloc d'identité en haut + note en bas) : leur
## nom de clé JSON dépend de la langue, contrairement aux champs "libres" qui
## s'affichent tels quels, dans l'ordre du JSON.
const NAME_KEY := {"fr": "Nom", "en": "Name"}
const FIRST_NAME_KEY := {"fr": "Prenom", "en": "First name"}
const AGE_KEY := {"fr": "Age", "en": "Age"}
const BIRTHPLACE_KEY := {"fr": "Lieu de naissance", "en": "Birthplace"}
const STATUS_KEY := {"fr": "Statut", "en": "Status"}
const NOTE_KEY := {"fr": "Note personnelle", "en": "Personal note"}
## Champ "alias/pseudo connu" — inclus dans la recherche floue en plus du nom
## et prénom, pour retrouver un personnage à partir d'un pseudo croisé ailleurs
## dans l'enquête (ex. "Lily11"), pas seulement son état civil.
const ALIAS_KEY := {"fr": "Pseudo(s) connu(s)", "en": "Known alias(es)"}
const PHOTO_KEY := "Photo"
const PLAYER_CHARACTER_ID := 0

## Casse + accents ignorés caractère par caractère (pas de regex) : une table
## de correspondance n'affecte que les lettres accentuées latines qu'elle
## connaît et laisse tout le reste — y compris des caractères non-latins
## comme le chinois — parfaitement intact.
const _ACCENT_MAP := {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "ì": "i", "í": "i",
	"ô": "o", "ö": "o", "ò": "o", "ó": "o", "õ": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c", "ñ": "n", "ÿ": "y", "œ": "oe", "æ": "ae",
}

## languageCode -> Array[Dictionary] (une entrée par personnage).
var _characters_by_locale: Dictionary = {}


func _init() -> void:
	_load()


## Cherche un personnage correspondant à `query`, dans la langue actuelle
## (Settings.locale). Insensible à la casse/aux accents, tolère nom et
## prénom inversés, et matche aussi un pseudo connu. Cas particulier : si
## `query` correspond au pseudo du joueur, renvoie toujours sa propre fiche
## (characterId 0). Renvoie un dictionnaire vide si rien ne correspond.
func search(query: String) -> Dictionary:
	var locale := _resolve_locale()
	var characters: Array = _characters_by_locale.get(locale, [])
	var normalized_query := _normalize(query)
	if normalized_query.is_empty():
		return {}

	if not PlayerSession.pseudo.is_empty() and normalized_query == _normalize(PlayerSession.pseudo):
		return _find_by_id(characters, PLAYER_CHARACTER_ID)

	var query_tokens: PackedStringArray = normalized_query.split(" ", false)
	if query_tokens.is_empty():
		return {}

	for character: Dictionary in characters:
		var haystack := _normalize(
			str(character.get(NAME_KEY[locale], "")) + " " +
			str(character.get(FIRST_NAME_KEY[locale], "")) + " " +
			str(character.get(ALIAS_KEY[locale], ""))
		)
		var matches_all := true
		for token in query_tokens:
			if not haystack.contains(token):
				matches_all = false
				break
		if matches_all:
			return character

	return {}


func header_keys() -> Dictionary:
	var locale := _resolve_locale()
	return {
		"name": NAME_KEY[locale],
		"first_name": FIRST_NAME_KEY[locale],
		"age": AGE_KEY[locale],
		"birthplace": BIRTHPLACE_KEY[locale],
		"status": STATUS_KEY[locale],
		"note": NOTE_KEY[locale],
		"photo": PHOTO_KEY,
	}


func _find_by_id(characters: Array, character_id: int) -> Dictionary:
	for character: Dictionary in characters:
		if int(character.get("characterId", -1)) == character_id:
			return character
	return {}


func _resolve_locale() -> String:
	if _characters_by_locale.has(Settings.locale):
		return Settings.locale
	return DEFAULT_LOCALE


func _normalize(text: String) -> String:
	var lowered := text.to_lower()
	var result := ""
	for i in lowered.length():
		var ch := lowered[i]
		result += _ACCENT_MAP.get(ch, ch)
	return result.strip_edges()


func _load() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("translations"):
		return
	for block: Dictionary in parsed["translations"]:
		_characters_by_locale[block.get("languageCode", "")] = block.get("characters", [])
