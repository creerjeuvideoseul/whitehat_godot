extends Control
class_name ClueFusion
## Encart de "fusion" de deux (ou trois) indices liés (voir clues_link.txt et
## ClueManager.completes_link/desktop.gd) : joué quand le joueur trouve la
## réponse à une question déjà connue (ou l'inverse). Chaque élément (carte
## IDClue1, symbole, carte IDClue2, etc.) reste invisible jusqu'à son tour
## puis "tombe" depuis au-dessus de sa position finale et atterrit avec une
## légère secousse — effet de pavé qui s'écrase, plus percutant qu'un simple
## fondu/envol (voir _drop_group) — avant qu'un son gratifiant ne se joue et
## que l'ensemble ne glisse vers la droite en direction du panneau latéral
## Collecte d'indices, même sens de sortie que ClueSpotlight, pour rester
## cohérent avec "un indice part vers le panneau".
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
## ClueBoardTooltip/ClueSpotlight) — chaque élément tombe ensuite depuis
## cette position finale déjà connue jusqu'à elle-même (voir _drop_group),
## un Container réécraserait la position pendant l'animation.

const CARD_WIDTH := 900.0
const CARD_GAP := 24.0
## Distance (en y) au-dessus de sa position finale d'où un élément part avant
## de "tomber" — assez grand pour lire clairement une chute, pas au point de
## ralentir la cascade (voir DROP_STAGGER_SECONDS).
const DROP_DISTANCE := 320.0
## Chute rapide et accélérée (EASE_IN, voir _drop_group) façon gravité —
## volontairement court pour rester percutant.
const FALL_SECONDS := 0.22
## Décalage entre le début de la chute d'un élément et celui du suivant —
## augmenté à 0.6s (l'ancienne valeur de 0.12s faisait trop se chevaucher
## les chutes) pour bien distinguer l'ordre question / symbole / réponse / ...
const DROP_STAGGER_SECONDS := 0.6
## Secousse horizontale à l'atterrissage : quelques allers-retours
## d'amplitude décroissante (dernier palier à 0 = retour au repos), voir
## _drop_group.
const SHAKE_STEP_SECONDS := 0.045
const SHAKE_OFFSETS: Array[float] = [10.0, -6.0, 3.0, -1.5, 0.0]
const HOLD_SECONDS := 3.0
## Avec 3 cartes (question+réponse+solution), une seconde de plus que
## HOLD_SECONDS : plus de texte à lire avant l'envol vers le panneau.
const HOLD_SECONDS_WITH_SOLUTION := 4.0
const EXIT_SECONDS := 0.5
const EXIT_SCALE := Vector2(0.3, 0.3)

signal finished

## Un fond par carte plutôt qu'un seul grand fond couvrant tout l'empilement :
## un fond unique laissait une bande plate (sans dégradé) bien visible entre
## les cartes, là où seul le halo flou du bord EXTÉRIEUR de l'empilement était
## adouci — voir échange avec l'utilisateur. Un fond par carte fait déborder
## le flou de chacune dans l'espacement qui la sépare des autres, donc plus
## aucune zone plate entre deux cartes.
##
## Les 3 fonds sont groupés en tête de l'arbre (voir clue_fusion.tscn), avant
## toutes les cartes : sans ça, AnswerBackdrop/SolutionBackdrop se
## retrouvaient APRÈS QuestionCard, donc leur ombre (shadow_size 300, voir
## StyleBoxFlat_backdrop) se dessinait par-dessus la carte précédente pendant
## sa chute — illisible. Ce regroupement les place tous derrière toutes les
## cartes SANS toucher à z_index — z_index compare globalement tout le canvas
## (pas seulement les enfants de ClueFusion) et avait fait passer les fonds
## derrière _window_layer, donc derrière le téléphone/SMS/galerie/coffre/mail
## de desktop.gd (voir échange avec l'utilisateur).
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

## Tous les Tweens en vol (un par groupe qui tombe, plus celui du
## palier/envol final) — suivis dans un tableau plutôt qu'une seule variable
## depuis que la cascade en lance plusieurs en parallèle, pour pouvoir tous
## les tuer d'un coup si une nouvelle fusion redémarre pendant que l'ancienne
## joue encore (voir _kill_tweens).
var _tweens: Array[Tween] = []
## Vrai si cette fusion a une 3e carte (solution distincte de la réponse) —
## voir show_fusion. Relu par _resize_to_content pour savoir si
## EqualsLabel/SolutionCard participent à l'empilement.
var _has_solution_card: bool = false


func _ready() -> void:
	hide()


func _kill_tweens() -> void:
	for t in _tweens:
		if is_instance_valid(t):
			t.kill()
	_tweens.clear()


## Joue la séquence complète (cascade de chutes, palier, son, envol vers la
## droite) puis émet `finished`. `question_id`/`answer_id` : voir
## ClueManager.get_link_partner/is_link_question pour déterminer lequel est
## lequel avant d'appeler ceci — cet encart ne connaît rien à la sémantique
## question/réponse, juste où poser chaque texte. `solution_id` : voir
## ClueManager.get_link_solution — égal à `answer_id` pour le format à deux
## cartes ("="), différent pour le format à trois cartes ("+" puis "=").
func show_fusion(question_id: String, answer_id: String, solution_id: String) -> void:
	_kill_tweens()

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
	for n: CanvasItem in [_question_backdrop, _question_card, _plus_label, _answer_backdrop, _answer_card, _equals_label, _solution_backdrop, _solution_card]:
		n.modulate.a = 0.0
	show()

	await _resize_to_content()

	## Cascade "pavé qui tombe" : chaque groupe (une carte + son fond, ou un
	## symbole seul) reste invisible jusqu'à son tour puis tombe et atterrit
	## en tremblant, avec un léger décalage avant que le suivant ne parte —
	## voir _drop_group.
	var drop_groups: Array = [
		[_question_card, _question_backdrop],
		[_plus_label],
		[_answer_card, _answer_backdrop],
	]
	if _has_solution_card:
		drop_groups.append([_equals_label])
		drop_groups.append([_solution_card, _solution_backdrop])

	var last_tween: Tween
	for i in drop_groups.size():
		last_tween = _drop_group(drop_groups[i])
		_tweens.append(last_tween)
		if i < drop_groups.size() - 1:
			await get_tree().create_timer(DROP_STAGGER_SECONDS).timeout
	await last_tween.finished

	var hold_tween := create_tween()
	_tweens.append(hold_tween)
	hold_tween.tween_interval(HOLD_SECONDS_WITH_SOLUTION if _has_solution_card else HOLD_SECONDS)
	hold_tween.tween_callback(func() -> void: SfxPlayer.play(SfxPlayer.CLUE_FUSION_SFX))

	hold_tween.set_ease(Tween.EASE_IN_OUT)
	hold_tween.set_trans(Tween.TRANS_LINEAR)
	hold_tween.set_parallel(true)
	## Cible absolue (pas relative à la position actuelle, déjà centrée) —
	## même calcul que ClueSpotlight._tween pour l'envol de sortie.
	var exit_target_x: float = get_viewport_rect().size.x + size.x
	hold_tween.tween_property(self, "position:x", exit_target_x, EXIT_SECONDS)
	hold_tween.tween_property(self, "modulate:a", 0.0, EXIT_SECONDS)
	hold_tween.tween_property(self, "scale", EXIT_SCALE, EXIT_SECONDS)
	hold_tween.chain().tween_callback(func() -> void:
		hide()
		finished.emit()
	)


## Fait "tomber" un groupe d'un ou deux nœuds (une carte + son fond, ou un
## symbole seul) depuis DROP_DISTANCE au-dessus de sa position finale
## (déjà posée par _resize_to_content, lue AVANT de la décaler vers le haut)
## jusqu'à cette position, avec une légère secousse horizontale à
## l'atterrissage. Retourne le Tween pour que l'appelant puisse attendre la
## fin du dernier groupe de la cascade (voir show_fusion) ou le suivre pour
## un kill (_kill_tweens).
func _drop_group(nodes: Array) -> Tween:
	var final_positions: Array[Vector2] = []
	for n: Control in nodes:
		final_positions.append(n.position)
		n.position.y -= DROP_DISTANCE
		n.modulate.a = 1.0

	var t := create_tween()
	t.set_parallel(true)
	for i in nodes.size():
		t.tween_property(nodes[i], "position:y", final_positions[i].y, FALL_SECONDS) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	## Secousse : allers-retours horizontaux à amplitude décroissante,
	## chaînés après la chute (chain() quitte le mode parallèle en cours) puis
	## repassés en parallèle à chaque palier pour garder la carte et son fond
	## synchronisés entre eux. Le son d'impact se joue à cet instant précis
	## (atterrissage), pas au début de la chute.
	t.chain()
	t.tween_callback(func() -> void: SfxPlayer.play(SfxPlayer.CLUE_DROP_SFX))
	for offset in SHAKE_OFFSETS:
		t.set_parallel(true)
		for i in nodes.size():
			t.tween_property(nodes[i], "position:x", final_positions[i].x + offset, SHAKE_STEP_SECONDS)
		t.chain()

	return t


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
