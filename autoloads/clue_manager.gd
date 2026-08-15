extends Node
## Autoload singleton : le domaine "collecte d'indices". Regroupe les
## définitions fixes par mission (catégories + indices, chargées une fois
## depuis data/*.txt, format CSV/point-virgule) et la progression du joueur
## (quels indices sont débloqués), pour ne pas éclater ce domaine entre
## plusieurs autoloads.
##
## Ces tables ne stockent que des identifiants ; le texte affiché passe
## toujours par tr() sur label_key / l'IDunique lui-même (voir
## translations/indices.csv), exactement comme ui.csv pour le reste de l'UI.
##
## Un indice se débloque via le tag [#indice=xxx] d'une ligne de dialogue
## (dialogue_manager), quel que soit l'écran qui l'affiche (balloon
## narratif, chat, futur mail/sms) — voir unlock_from_tags().

## Extension .txt (pas .csv) volontairement : un .csv est automatiquement pris
## en charge par l'importeur "CSV Translation" natif de Godot, qui ne conserve
## que la ressource de traduction convertie à l'export — le fichier source
## brut n'est alors plus lisible via FileAccess.open() dans un build exporté
## (ça marchait dans l'éditeur car res:// pointe directement sur les fichiers
## du projet). En .txt, Godot ne reconnaît aucun importeur : le fichier reste
## un fichier brut normal, correctement inclus par le filtre d'export
## "data/*.txt" (voir export_presets.cfg). Le format interne (point-virgule)
## ne change pas.
const CATEGORIES_CSV_PATH := "res://data/clue_categories.txt"
const CLUES_CSV_PATH := "res://data/clues.txt"
const CSV_DELIMITER := ";"

## Catégorie de l'indice de résolution principal d'une mission (ex.
## M1_SOLUTION_OU) — affichée sur le tableau comme les autres (voir
## clue_categories.txt), mais dans un style distinct (voir ClueBoard, fond
## bleu Palette.CLUE_SOLUTION_*) puisqu'elle sert aussi de déclencheur
## générique pour le rapport de mission : chaque future mission n'a qu'à
## donner cette catégorie à son propre indice de résolution, rien à coder de
## spécifique par mission. Distincte de FINSECONDAIRE (fin secondaire/bonus),
## qui ne déclenche rien mais partage le même style "résolution".
const SOLUTION_CATEGORY_ID := "FIN"

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
## ET ayant au moins un indice déjà débloqué (pas juste "associé" — un
## personnage qu'on n'a pas encore rencontré n'a aucune raison d'apparaître
## sur le tableau, avatar compris). Volontairement basé sur l'unlock plutôt
## que sur un nouveau champ "à afficher à partir de..." : chaque indice se
## débloque déjà exactement au moment où son contenu apparaît au joueur, donc
## cette règle s'auto-gère pour toutes les missions futures sans rien à
## renseigner en plus dans les données.
func get_categories_for_mission(mission_id: int) -> Array[ClueCategory]:
	var seen: Dictionary = {}
	var result: Array[ClueCategory] = []
	for clue in _clues:
		if not _clue_visible_for_mission(clue, mission_id) or seen.has(clue.category_id) or not is_unlocked(clue.id):
			continue
		var categ: ClueCategory = _categories.get(clue.category_id)
		if categ != null and categ.is_display:
			seen[clue.category_id] = true
			result.append(categ)
	return result


## Vrai si `clue` doit apparaître sur le tableau ouvert pour `mission_id` :
## soit sa propre mission, soit la mission "0" — convention réservée aux
## indices hors mission (ex. RelayGhost, voir intro_relay_perseverant plus
## bas), toujours visibles quelle que soit la mission en cours.
func _clue_visible_for_mission(clue: ClueDefinition, mission_id: int) -> bool:
	return clue.mission_id == mission_id or clue.mission_id == 0


## Vrai si l'enquête de cette mission a réellement commencé : au moins un
## indice débloqué dont l'id suit la convention "M<mission_id>_..." (voir
## clues.txt). Volontairement plus strict que "la mission a au moins un
## indice débloqué" : l'indice de fin d'intro de RelayGhost (intro_relay_perseverant)
## ne suit pas cette convention et ne doit pas suffire à faire apparaître le
## titre de la fenêtre Collecte d'indices avant que le joueur n'ait vraiment
## commencé à fouiller le téléphone d'Alizée (voir ClueBoardWindow).
func has_mission_started(mission_id: int) -> bool:
	var prefix := "M%d_" % mission_id
	for clue in _clues:
		if clue.mission_id == mission_id and clue.id.begins_with(prefix) and is_unlocked(clue.id):
			return true
	return false


## L'id de catégorie d'un indice donné, ou une chaîne vide si l'id n'existe
## pas — pour ClueBoard, qui a besoin de savoir si un indice fraîchement
## débloqué appartient à une catégorie déjà affichée ou doit en révéler une
## nouvelle (voir ClueBoard._on_clue_unlocked).
func get_category_id_for_clue(clue_id: String) -> String:
	for clue in _clues:
		if clue.id == clue_id:
			return clue.category_id
	return ""


## Vrai si `clue_id` est l'indice de résolution principal de sa mission (voir
## SOLUTION_CATEGORY_ID) — pour desktop_header.gd, qui n'a besoin de savoir
## que "est-ce que l'indice qui vient de se débloquer est LE bon", pas de
## connaître un mission_id précis.
func is_solution_clue(clue_id: String) -> bool:
	return get_category_id_for_clue(clue_id) == SOLUTION_CATEGORY_ID


## Vrai si la résolution de cette mission précise est déjà débloquée — scopé
## par mission_id (pas juste "un indice FIN débloqué, n'importe lequel") pour
## rester correct une fois plusieurs missions jouées dans la même sauvegarde :
## la mission 2 ne doit pas hériter du rapport déjà généré de la mission 1.
func has_unlocked_mission_solution(mission_id: int) -> bool:
	for clue in _clues:
		if clue.mission_id == mission_id and clue.category_id == SOLUTION_CATEGORY_ID and is_unlocked(clue.id):
			return true
	return false


func get_clues_for_category(mission_id: int, category_id: String) -> Array[ClueDefinition]:
	var result: Array[ClueDefinition] = []
	for clue in _clues:
		if _clue_visible_for_mission(clue, mission_id) and clue.category_id == category_id:
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
