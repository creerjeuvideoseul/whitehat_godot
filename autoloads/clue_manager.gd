extends Node
## Autoload singleton : le domaine "collecte d'indices". Regroupe les
## définitions fixes par mission (catégories + indices, chargées une fois
## depuis data/*.csv) et la progression du joueur (quels indices sont
## débloqués), pour ne pas éclater ce domaine entre plusieurs autoloads.
##
## Les tables CSV ne stockent que des identifiants ; le texte affiché passe
## toujours par tr() sur label_key / l'IDunique lui-même (voir
## translations/indices.csv), exactement comme ui.csv pour le reste de l'UI.
##
## Un indice se débloque via le tag [#indice=xxx] d'une ligne de dialogue
## (dialogue_manager), quel que soit l'écran qui l'affiche (balloon
## narratif, chat, futur mail/sms) — voir unlock_from_tags().

const CATEGORIES_CSV_PATH := "res://data/clue_categories.csv"
const CLUES_CSV_PATH := "res://data/clues.csv"
const CSV_DELIMITER := ";"

## Emis quand un nouvel indice est débloqué (pas rejoué si déjà connu) —
## utile plus tard pour une notification/toast "nouvel indice".
signal clue_unlocked(clue_id: String)

## Emis par unlock_all()/lock_all() (outil de debug) : contrairement à
## clue_unlocked, pas d'id précis puisque tout change d'un coup — les écrans
## affichant des indices doivent se rafraîchir entièrement sur ce signal.
signal all_unlocked_changed


var _categories: Dictionary = {}
var _clues: Array[ClueDefinition] = []
var _unlocked_ids: Dictionary = {}


func _ready() -> void:
	_load_categories()
	_load_clues()


## Débloque un indice par son id. Sans effet s'il l'est déjà (idempotent).
func unlock(clue_id: String) -> void:
	if clue_id.is_empty() or _unlocked_ids.has(clue_id):
		return
	_unlocked_ids[clue_id] = true
	clue_unlocked.emit(clue_id)


## A appeler sur chaque ligne de dialogue affichée (balloon, chat...) :
## débloque l'indice si la ligne porte un tag [#indice=xxx], ne fait rien
## sinon. Sûr d'appeler systématiquement, la plupart des lignes n'ont pas ce tag.
func unlock_from_tags(line: DialogueLine) -> void:
	if line.has_tag("indice"):
		unlock(line.get_tag_value("indice"))


func is_unlocked(clue_id: String) -> bool:
	return _unlocked_ids.has(clue_id)


## Pour SaveManager : snapshot/restauration de la progression du joueur.
func get_unlocked_ids() -> Array:
	return _unlocked_ids.keys()


func load_unlocked_ids(ids: Array) -> void:
	_unlocked_ids.clear()
	for id in ids:
		_unlocked_ids[id] = true


## Debug only (see Settings.IS_PRODUCTION) : débloque tous les indices de
## toutes les missions chargées, sans passer par le tag [#indice=xxx]. Casse
## volontairement la cohérence de la sauvegarde — c'est un outil de test, pas
## une fonctionnalité de jeu.
func unlock_all() -> void:
	for clue in _clues:
		_unlocked_ids[clue.id] = true
	all_unlocked_changed.emit()


## Debug only : symétrique de unlock_all().
func lock_all() -> void:
	_unlocked_ids.clear()
	all_unlocked_changed.emit()


func get_category(category_id: String) -> ClueCategory:
	return _categories.get(category_id)


## Catégories réellement pertinentes pour cette mission : marquées affichables
## ET ayant au moins un indice associé (une catégorie sans indice pour cette
## mission n'apparaît pas sur le tableau).
func get_categories_for_mission(mission_id: int) -> Array[ClueCategory]:
	var seen: Dictionary = {}
	var result: Array[ClueCategory] = []
	for clue in _clues:
		if clue.mission_id != mission_id or seen.has(clue.category_id):
			continue
		var categ: ClueCategory = _categories.get(clue.category_id)
		if categ != null and categ.is_display:
			seen[clue.category_id] = true
			result.append(categ)
	return result


func get_clues_for_category(mission_id: int, category_id: String) -> Array[ClueDefinition]:
	var result: Array[ClueDefinition] = []
	for clue in _clues:
		if clue.mission_id == mission_id and clue.category_id == category_id:
			result.append(clue)
	return result


func _load_categories() -> void:
	var file := FileAccess.open(CATEGORIES_CSV_PATH, FileAccess.READ)
	if file == null:
		return
	file.get_csv_line(CSV_DELIMITER)
	while not file.eof_reached():
		var row := file.get_csv_line(CSV_DELIMITER)
		if row.size() < 4 or row[0].is_empty():
			continue
		var categ := ClueCategory.new()
		categ.id = row[0]
		categ.label_key = row[1]
		categ.image_path = row[2]
		categ.is_display = row[3] == "1"
		_categories[categ.id] = categ


func _load_clues() -> void:
	var file := FileAccess.open(CLUES_CSV_PATH, FileAccess.READ)
	if file == null:
		return
	file.get_csv_line(CSV_DELIMITER)
	while not file.eof_reached():
		var row := file.get_csv_line(CSV_DELIMITER)
		if row.size() < 3 or row[0].is_empty():
			continue
		var clue := ClueDefinition.new()
		clue.mission_id = int(row[0])
		clue.id = row[1]
		clue.category_id = row[2]
		_clues.append(clue)
