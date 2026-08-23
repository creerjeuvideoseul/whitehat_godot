extends Control
class_name ClueFusion
## Encart de "fusion" de deux (ou trois) indices liés (voir clues_link.txt et
## ClueManager.completes_link/desktop.gd) : joué quand le joueur trouve la
## réponse à une question déjà connue (ou l'inverse) — la question s'envole
## depuis la droite (effet inversé de ClueSpotlight, qui s'y envole EN
## sortie) et vient se poser en haut, la réponse apparaît en dessous, un "+"
## ou un "=" jaune lumineux les relie (voir show_fusion), l'ensemble reste
## affiché un instant, un son gratifiant se joue, puis tout glisse vers la
## droite en direction du panneau latéral Collecte d'indices — même sens de
## sortie que ClueSpotlight, pour rester cohérent avec "un indice part vers
## le panneau".
##
## Deux formats, selon que la paire révèle une vraie 3e "solution" distincte
## de la réponse (colonne IDClueSolution de clues_link.txt, voir
## ClueManager.get_link_solution) :
## - Sans solution distincte (solution == réponse) : question / "=" / réponse,
##   deux cartes seulement — la réponse EST la solution.
## - Avec solution distincte : question / "+" / réponse / "=" / solution,
##   trois cartes — question + réponse s'additionnent en une conclusion à part.
##
## Instance unique réutilisée par desktop.gd (comme ClueSpotlight) plutôt que
## recréée à chaque fusion — un nouvel appel pendant qu'une séquence
## précédente joue encore interrompt celle-ci et repart de zéro.
##
## Positionnement manuel (pas de VBoxContainer) : cartes/symboles sont
## empilés à la main une fois leur taille minimale connue (voir
## _resize_to_content, même recette d'attente de deux frames que
## ClueBoardTooltip/ClueSpotlight), pour pouvoir animer la position de
## QuestionCard indépendamment du reste sans qu'un Container ne la
## réécrase au prochain tri.

const CARD_WIDTH := 900.0
const CARD_GAP := 24.0
const ENTRANCE_SECONDS := 0.5
## Distance (en x) d'où QuestionCard part avant de glisser jusqu'à sa
## position finale — assez grand pour venir clairement de hors-écran à
## droite quel que soit l'endroit où l'encart se retrouve centré.
const ENTRANCE_OFFSET := 500.0
const REVEAL_SECONDS := 0.3
const HOLD_SECONDS := 3.0
const EXIT_SECONDS := 0.5
const EXIT_SCALE := Vector2(0.3, 0.3)

signal finished

## Un fond par carte plutôt qu'un seul grand fond couvrant tout l'empilement :
## un fond unique laissait une bande plate (sans dégradé) bien visible entre
## les cartes, là où seul le halo flou du bord EXTÉRIEUR de l'empilement était
## adouci — voir échange avec l'utilisateur. Un fond par carte fait déborder
## le flou de chacune dans l'espacement qui la sépare des autres, donc plus
## aucune zone plate entre deux cartes.
@onready var _question_backdrop: Panel = %QuestionBackdrop
@onready var _question_card: PanelContainer = %QuestionCard
@onready var _question_label: RichTextLabel = %QuestionLabel
@onready var _plus_label: Label = %PlusLabel
@onready var _answer_backdrop: Panel = %AnswerBackdrop
@onready var _answer_card: PanelContainer = %AnswerCard
@onready var _answer_label: RichTextLabel = %AnswerLabel
@onready var _equals_label: Label = %EqualsLabel
@onready var _solution_backdrop: Panel = %SolutionBackdrop
@onready var _solution_card: PanelContainer = %SolutionCard
@onready var _solution_label: RichTextLabel = %SolutionLabel

var _tween: Tween
## Vrai si cette fusion a une 3e carte (solution distincte de la réponse) —
## voir show_fusion. Relu par _resize_to_content pour savoir si
## EqualsLabel/SolutionCard participent à l'empilement.
var _has_solution_card: bool = false


func _ready() -> void:
	hide()


## Joue la séquence complète (entrée de la question, apparition de la
## réponse et du symbole, palier, son, envol vers la droite) puis émet
## `finished`. `question_id`/`answer_id` : voir ClueManager.get_link_partner/
## is_link_question pour déterminer lequel est lequel avant d'appeler ceci —
## cet encart ne connaît rien à la sémantique question/réponse, juste où
## poser chaque texte. `solution_id` : voir ClueManager.get_link_solution —
## égal à `answer_id` pour le format à deux cartes ("="), différent pour le
## format à trois cartes ("+" puis "=").
func show_fusion(question_id: String, answer_id: String, solution_id: String) -> void:
	if is_instance_valid(_tween):
		_tween.kill()

	_has_solution_card = solution_id != answer_id

	_question_label.text = RichTextMarkup.html_to_bbcode(tr(question_id))
	_answer_label.text = RichTextMarkup.html_to_bbcode(tr(answer_id))
	_plus_label.text = "+" if _has_solution_card else "="
	_equals_label.visible = _has_solution_card
	_solution_card.visible = _has_solution_card
	_solution_backdrop.visible = _has_solution_card
	if _has_solution_card:
		_solution_label.text = RichTextMarkup.html_to_bbcode(tr(solution_id))

	position = Vector2.ZERO
	scale = Vector2.ONE
	modulate = Color.WHITE
	_question_backdrop.modulate.a = 0.0
	_question_card.modulate.a = 0.0
	_answer_backdrop.modulate.a = 0.0
	_answer_card.modulate.a = 0.0
	_plus_label.modulate.a = 0.0
	_equals_label.modulate.a = 0.0
	_solution_backdrop.modulate.a = 0.0
	_solution_card.modulate.a = 0.0
	show()

	await _resize_to_content()

	## QuestionBackdrop suit QuestionCard pendant son envol d'entrée (même
	## décalage, même tween) — sinon son fond serait déjà visible, immobile,
	## pendant que la carte vole encore vers lui depuis la droite.
	var question_final_x: float = _question_card.position.x
	var question_backdrop_final_x: float = _question_backdrop.position.x
	_question_card.position.x = question_final_x + ENTRANCE_OFFSET
	_question_backdrop.position.x = question_backdrop_final_x + ENTRANCE_OFFSET
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_question_card, "position:x", question_final_x, ENTRANCE_SECONDS)
	_tween.parallel().tween_property(_question_backdrop, "position:x", question_backdrop_final_x, ENTRANCE_SECONDS)
	_tween.parallel().tween_property(_question_card, "modulate:a", 1.0, ENTRANCE_SECONDS)
	_tween.parallel().tween_property(_question_backdrop, "modulate:a", 1.0, ENTRANCE_SECONDS)

	_tween.tween_property(_answer_card, "modulate:a", 1.0, REVEAL_SECONDS)
	_tween.parallel().tween_property(_answer_backdrop, "modulate:a", 1.0, REVEAL_SECONDS)
	_tween.parallel().tween_property(_plus_label, "modulate:a", 1.0, REVEAL_SECONDS)

	if _has_solution_card:
		_tween.tween_property(_solution_card, "modulate:a", 1.0, REVEAL_SECONDS)
		_tween.parallel().tween_property(_solution_backdrop, "modulate:a", 1.0, REVEAL_SECONDS)
		_tween.parallel().tween_property(_equals_label, "modulate:a", 1.0, REVEAL_SECONDS)

	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_callback(func() -> void: SfxPlayer.play(SfxPlayer.CLUE_FUSION_SFX))

	## Revient aux réglages par défaut du Tween (linéaire) pour l'envol final :
	## EASE_OUT/TRANS_CUBIC ci-dessus n'était voulu que pour l'entrée de
	## QuestionCard, pas pour la sortie — même style neutre que l'envol de
	## ClueSpotlight, qui ne personnalise pas non plus sa courbe de sortie.
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.set_parallel(true)
	## Cible absolue (pas relative à la position actuelle, déjà centrée) —
	## même calcul que ClueSpotlight._tween pour l'envol de sortie.
	var exit_target_x: float = get_viewport_rect().size.x + size.x
	_tween.tween_property(self, "position:x", exit_target_x, EXIT_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, EXIT_SECONDS)
	_tween.tween_property(self, "scale", EXIT_SCALE, EXIT_SECONDS)
	_tween.chain().tween_callback(func() -> void:
		hide()
		finished.emit()
	)


## Mesure la taille réelle de chaque carte/symbole présent (texte fraîchement
## posé, largeur fixe CARD_WIDTH pour les cartes) puis les empile à la main,
## le tout centré à l'écran — deux frames d'attente, même recette que
## ClueBoardTooltip._resize_to_content. EqualsLabel/SolutionCard n'entrent
## dans le calcul que si _has_solution_card (voir show_fusion) ; sinon
## PlusLabel (devenu "=") reste le seul symbole, juste après AnswerCard.
func _resize_to_content() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var question_size: Vector2 = _question_card.get_combined_minimum_size()
	var plus_size: Vector2 = _plus_label.get_minimum_size()
	var answer_size: Vector2 = _answer_card.get_combined_minimum_size()
	var total_height: float = question_size.y + CARD_GAP + plus_size.y + CARD_GAP + answer_size.y

	var equals_size := Vector2.ZERO
	var solution_size := Vector2.ZERO
	if _has_solution_card:
		equals_size = _equals_label.get_minimum_size()
		solution_size = _solution_card.get_combined_minimum_size()
		total_height += CARD_GAP + equals_size.y + CARD_GAP + solution_size.y

	size = Vector2(CARD_WIDTH, total_height)
	pivot_offset = size / 2.0
	global_position = (get_viewport_rect().size - size) / 2.0

	var cursor_y := 0.0
	_question_card.position = Vector2((CARD_WIDTH - question_size.x) * 0.5, cursor_y)
	_question_card.size = question_size
	_question_backdrop.position = _question_card.position
	_question_backdrop.size = question_size
	cursor_y += question_size.y + CARD_GAP

	_plus_label.position = Vector2((CARD_WIDTH - plus_size.x) * 0.5, cursor_y)
	_plus_label.size = plus_size
	cursor_y += plus_size.y + CARD_GAP

	_answer_card.position = Vector2((CARD_WIDTH - answer_size.x) * 0.5, cursor_y)
	_answer_card.size = answer_size
	_answer_backdrop.position = _answer_card.position
	_answer_backdrop.size = answer_size
	cursor_y += answer_size.y + CARD_GAP

	if _has_solution_card:
		_equals_label.position = Vector2((CARD_WIDTH - equals_size.x) * 0.5, cursor_y)
		_equals_label.size = equals_size
		cursor_y += equals_size.y + CARD_GAP

		_solution_card.position = Vector2((CARD_WIDTH - solution_size.x) * 0.5, cursor_y)
		_solution_card.size = solution_size
		_solution_backdrop.position = _solution_card.position
		_solution_backdrop.size = solution_size
