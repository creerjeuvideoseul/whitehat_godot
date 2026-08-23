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
## Un indice se débloque au clic sur son passage color=indice, quel que soit
## l'écran qui l'affiche (balloon narratif, chat, mail/SMS, fiche OSINT...) —
## voir mark_clicked() et RichTextMarkup.wire_indice_interactions().

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
## Paires d'indices liés "question -> réponse" (voir _load_links) : trouver
## la réponse gratifie le joueur d'une fusion visuelle (voir desktop.gd,
## ClueFusion) et fait disparaître la question de la liste NARROW du panneau
## Collecte d'indices (voir DesktopCluePanel._rebuild_content), la réponse
## répondant déjà à sa place.
const LINKS_CSV_PATH := "res://data/clues_link.txt"
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

## Emis à chaque clic sur un passage color=indice, y compris sur un indice
## déjà débloqué — contrairement à clue_unlocked (gelé après le premier
## déclenchement), c'est ce signal qui rejoue l'encart central (voir
## ClueSpotlight) et redéploie le panneau latéral (voir desktop.gd).
signal clue_clicked(clue_id: String)

## Emis par unlock_all()/lock_all() (outil de debug) : contrairement à
## clue_unlocked, pas d'id précis puisque tout change d'un coup — les écrans
## affichant des indices doivent se rafraîchir entièrement sur ce signal.
signal all_unlocked_changed


var _categories: Dictionary = {}
var _clues: Array[ClueDefinition] = []
var _unlocked_ids: Dictionary = {}
## clue_id "question" (IDClue1 dans clues_link.txt) -> clue_id "réponse"
## (IDClue2) — voir _load_links(). Une question n'a jamais qu'une seule
## réponse dans les données actuelles, donc une Dictionary simple suffit.
var _link_answer_of_question: Dictionary = {}
## Sens inverse de _link_answer_of_question, pour une recherche O(1) depuis
## la réponse plutôt que de reparcourir la table à l'envers à chaque appel.
var _link_question_of_answer: Dictionary = {}
## clue_id "question" -> clue_id "solution" (colonne IDClueSolution de
## clues_link.txt) — égal à la réponse elle-même (voir _link_answer_of_question)
## quand la paire n'a pas de 3e indice propre (cas le plus courant : "trouver
## la réponse répond déjà à la question"), différent quand la fusion des deux
## révèle un 3e indice à part entière, débloqué automatiquement à ce
## moment-là (voir desktop.gd::_on_clue_clicked).
var _link_solution_of_question: Dictionary = {}


func _ready() -> void:
	_load_categories()
	_load_clues()
	_load_links()


## Débloque un indice par son id. Sans effet s'il l'est déjà (idempotent).
func unlock(clue_id: String) -> void:
	if clue_id.is_empty() or _unlocked_ids.has(clue_id):
		return
	_unlocked_ids[clue_id] = true
	clue_unlocked.emit(clue_id)


## A appeler quand le joueur clique un passage color=indice (voir
## RichTextMarkup.wire_indice_interactions) — remplace l'ancien déblocage
## automatique "à la simple apparition à l'écran" (IndiceRevealTracker,
## supprimé). unlock() reste idempotent (effets de découverte joués une seule
## fois) ; clue_clicked, lui, se rejoue à chaque clic.
func mark_clicked(clue_id: String) -> void:
	unlock(clue_id)
	clue_clicked.emit(clue_id)


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


## Remet la progression à zéro (voir save_manager.gd::delete_save) —
## distinct de lock_all() ci-dessus, qui est un outil de debug avec sa propre
## sémantique de signal (rafraîchir une fenêtre déjà ouverte) ; ici on quitte
## le menu vers une toute nouvelle partie, rien n'écoute encore
## all_unlocked_changed. Simple alias de load_unlocked_ids([]) plutôt qu'une
## seconde implémentation du même vidage.
func reset() -> void:
	load_unlocked_ids([])


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
		clue.date = row[3] if row.size() > 3 else ""
		_clues.append(clue)


func _load_links() -> void:
	var file := FileAccess.open(LINKS_CSV_PATH, FileAccess.READ)
	if file == null:
		return
	file.get_csv_line(CSV_DELIMITER)
	while not file.eof_reached():
		var row := file.get_csv_line(CSV_DELIMITER)
		if row.size() < 3 or row[1].is_empty() or row[2].is_empty():
			continue
		_link_answer_of_question[row[1]] = row[2]
		_link_question_of_answer[row[2]] = row[1]
		## Colonne IDClueSolution optionnelle (rétrocompatible avec un
		## clues_link.txt à seulement 3 colonnes) : sans elle, la solution
		## EST la réponse elle-même (voir _link_solution_of_question).
		_link_solution_of_question[row[1]] = row[3] if row.size() > 3 and not row[3].is_empty() else row[2]


## Le partenaire lié de `clue_id` dans clues_link.txt (question -> réponse ou
## l'inverse), ou une chaîne vide s'il n'appartient à aucune paire — pour
## desktop.gd, qui doit savoir si l'indice qui vient de se débloquer complète
## une paire déjà à moitié connue (voir completes_link ci-dessous).
func get_link_partner(clue_id: String) -> String:
	if _link_answer_of_question.has(clue_id):
		return _link_answer_of_question[clue_id]
	return _link_question_of_answer.get(clue_id, "")


## Vrai si `clue_id` est le côté "question" (IDClue1) d'une paire liée — pour
## savoir, une fois qu'on sait qu'une paire est complète, quel côté est la
## question (à faire disparaître de la liste NARROW, voir
## is_superseded_by_link) et lequel est la réponse.
func is_link_question(clue_id: String) -> bool:
	return _link_answer_of_question.has(clue_id)


## Vrai si `clue_id` a un partenaire dans clues_link.txt et que ce partenaire
## est déjà débloqué, peu importe le sens (question comme réponse) — le
## déblocage de `clue_id` vient donc de "compléter" une paire liée. Voir
## desktop.gd::_on_clue_unlocked_for_link, qui l'utilise pour savoir si
## l'animation de fusion (ClueFusion) doit remplacer le spotlight simple.
func completes_link(clue_id: String) -> bool:
	var partner_id := get_link_partner(clue_id)
	return not partner_id.is_empty() and is_unlocked(partner_id)


## La "solution" de la paire dont `question_id` est le côté question (colonne
## IDClueSolution de clues_link.txt) — égale à la réponse elle-même si la
## paire n'a pas de 3e indice propre (voir _load_links). Chaîne vide si
## `question_id` n'est pas une question liée.
func get_link_solution(question_id: String) -> String:
	return _link_solution_of_question.get(question_id, "")


## Vrai si `clue_id` (question OU réponse d'une paire liée) doit disparaître
## de la liste NARROW une fois la fusion complète — pour DesktopCluePanel :
## - une question disparaît dès que sa réponse est débloquée, la réponse
##   répondant déjà à sa place (voir clues_link.txt) ;
## - la réponse, elle, ne disparaît QUE si la paire révèle une vraie solution
##   distincte (get_link_solution != la réponse elle-même) et que celle-ci
##   est débloquée — c'est alors la solution qui prend sa place, pas la
##   réponse. Sans solution distincte, la réponse reste affichée (comportement
##   d'origine).
## Le tableau d'enquête FULL (ClueBoard), lui, continue de tout montrer.
func is_superseded_by_link(clue_id: String) -> bool:
	if _link_answer_of_question.has(clue_id):
		return is_unlocked(_link_answer_of_question[clue_id])
	var question_id: String = _link_question_of_answer.get(clue_id, "")
	if question_id.is_empty():
		return false
	var solution_id := get_link_solution(question_id)
	return solution_id != clue_id and is_unlocked(solution_id)


## Vrai si `clue_id` est la solution d'une paire liée (CAS 1 : sa colonne
## IDClueSolution propre ; CAS 2 : la réponse elle-même, voir
## get_link_solution) dont la question ET la réponse sont TOUTES LES DEUX
## débloquées — la fusion a donc réellement eu lieu, pas seulement "clue_id
## se trouve être une réponse dont la question n'a pas encore été trouvée"
## (voir CAS 3, aucune fusion). Pour DesktopCluePanel, qui distingue
## visuellement ces bulles (fond différent, voir _build_clue_bubble) une fois
## qu'elles représentent effectivement une fusion résolue.
func is_link_solution(clue_id: String) -> bool:
	for question_id in _link_solution_of_question:
		if _link_solution_of_question[question_id] == clue_id and is_unlocked(question_id) and is_unlocked(clue_id):
			return true
	return false
