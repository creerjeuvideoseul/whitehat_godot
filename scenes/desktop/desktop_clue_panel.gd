extends Control
class_name DesktopCluePanel
## Panneau permanent ancré au bord droit de l'écran (voir desktop.tscn) —
## distinct des fenêtres de WindowLayer (ChatWindow, OsintWindow...) :
## jamais réduit dans la barre des tâches, seulement rétractable/déployable
## sur lui-même, sur 3 niveaux :
##
## Nœud placé APRÈS WindowLayer dans desktop.tscn : l'ordre des enfants d'un
## Control pilote l'empilement visuel (dernier enfant = premier plan, voir
## desktop.gd::_bring_window_to_front), donc ce panneau doit rester devant le
## téléphone d'Alizée et les autres fenêtres du bureau une fois déployé
## (NARROW/FULL) — sauf devant les terminaux "système" (TerminalConsole
## ajoutés directement en enfant de Desktop, ex. dump de données après Jean),
## qui restent au-dessus puisqu'ils s'ajoutent encore plus tard à l'arbre.
## - COLLAPSED : collé au bord droit, seuls COLLAPSED_VISIBLE_WIDTH px visibles.
## - NARROW : largeur EXPANDED_WIDTH, liste d'indices débloqués (bulles).
## - FULL : FULL_WIDTH_RATIO de l'écran, affiche la question de mission +
##   le tableau d'enquête par catégorie (ClueBoard) + le bouton Générer le
##   rapport — seul point d'entrée vers la collecte d'indices désormais,
##   l'ancienne fenêtre dédiée (ClueBoardWindow, ouverte depuis le bouton
##   "Indice" du header) a été retirée une fois ce panneau en place.
##
## Bordure/coins droits volontairement absents (voir StyleBoxFlat_bg/
## StyleBoxFlat_border_overlay dans la scène, border_width_right = 0 et
## corner_radius_*_right = 0) : le panneau est censé se fondre dans le bord de
## l'écran auquel il est collé plutôt que de paraître flotter devant.
##
## clip_contents = true (scène) : seul panneau du jeu à animer sa propre
## largeur/position via Tween (voir _animate_box, "size:x"/"position:x") — ce
## qui expose TitleBar, masquée puis réaffichée à chaque glissement (voir
## _show_title_bar), à un débordement visuel persistant de son fond/trait du
## bas côté gauche à chaque transition (NARROW comme FULL), reproductible en
## jeu comme dans l'éditeur (voir échange avec l'utilisateur). Cause exacte
## non identifiée avec certitude malgré plusieurs pistes explorées (rayon
## d'arrondi, resynchronisation manuelle de la largeur) ; clip_contents
## garantit qu'aucun enfant ne peut plus dépasser visuellement de ce cadre,
## quelle que soit la cause précise.
##
## Contenu NARROW rempli au fil des indices débloqués (voir _rebuild_content) :
## un indice = une "bulle", même recette visuelle que ChatBubble (voir
## chat_bubble.gd) plutôt qu'une nouvelle instanciée de la scène (pas de
## DialogueLine ici, un texte déjà traduit suffit, sans effet de frappe ni
## bulle "joueur" à droite). Regroupés par catégorie (IdCategUnique, même
## découpage que ClueBoard) puis triés par ClueDate — la date de l'indice
## lui-même, pas sa date de découverte — à l'intérieur de chaque catégorie.
## clues_link.txt (fusion d'indices liés) n'est volontairement pas pris en
## compte ici, chantier séparé à venir.

enum PanelState { COLLAPSED, NARROW, FULL }

## Largeur du panneau NARROW — 400 + les ~118px regagnés en réduisant la
## largeur du téléphone d'Alizée (voir alizee_phone.tscn, offset_right), + 20px
## de plus (deux fois 10px) pour absorber l'espace libéré par les décalages
## successifs à gauche de PhoneSectionHost (voir desktop.tscn) et garder
## inchangé l'écart entre la fenêtre SMS/Mail/Galerie/Coffre et ce panneau.
const EXPANDED_WIDTH := 538.23
## Largeur qui reste visible une fois COLLAPSED (le reste glisse hors écran,
## le panneau étant déjà collé au bord droit) — juste assez pour rester
## repérable et cliquable, sans prendre de place inutile sur le bureau.
const COLLAPSED_VISIBLE_WIDTH := 30.0
const SLIDE_OFFSET := EXPANDED_WIDTH - COLLAPSED_VISIBLE_WIDTH
const SLIDE_SECONDS := 0.4
## Largeur minimale forcée de ContentList (voir _ready) — celle du contenu en
## NARROW (EXPANDED_WIDTH moins les marges gauche/droite de ContentMargin
## dans la scène, 24px chacune). Un ScrollContainer à l'axe horizontal
## désactivé (Body.horizontal_scroll_mode, voir la scène) adopte de toute
## façon la largeur minimale de son contenu plutôt que de la réduire — voir
## échange avec l'utilisateur, un bug (largeur du panneau parfois mal
## recalculée par le moteur au niveau COLLAPSED) faisait retomber les bulles
## sur cette largeur réduite, écrasant leur texte au lieu de rester
## simplement hors champ comme prévu par le design (voir
## COLLAPSED_VISIBLE_WIDTH). Fixer cette largeur au niveau de ContentList
## rend les bulles immunes à ce bug, quelle que soit sa cause exacte.
const CONTENT_LIST_MIN_WIDTH := EXPANDED_WIDTH - 48.0
## Largeur du panneau FULL — recouvre la majorité de l'écran (fenêtres
## SMS/Mail/Galerie/Coffre comprises) sans le masquer entièrement. Augmenté
## de 0.9 à 0.97 (le tableau d'enquête à 3 colonnes, voir ClueBoard.COLS_PER_ROW,
## avait besoin de plus de place : à 0.9 le bouton "Générer le rapport" et le
## bord droit du tableau se retrouvaient tronqués). La formule de target_x
## dans _apply_state garde le bord DROIT du panneau fixe quel que soit ce
## ratio — augmenter FULL_WIDTH_RATIO agrandit donc uniquement vers la
## gauche, jamais vers la droite.
const FULL_WIDTH_RATIO := 0.97
## Marge conservée entre le bord droit du panneau FULL et le bord réel de
## l'écran — sans elle, le panneau finissait pile sur le bord de l'écran
## (aucune tolérance), ce qui suffisait à tronquer les éléments collés à
## droite (bouton Générer le rapport, ascenseur vertical du tableau, bouton →).
const FULL_RIGHT_MARGIN := 16.0
## Fondu du contenu (liste <-> graph) lors d'un passage NARROW<->FULL — voir
## _cross_fade. Volontairement plus court que SLIDE_SECONDS : le contenu
## sortant s'efface vite en début de glissement, le contenu entrant apparaît
## juste après que le cadre a fini de bouger (voir le délai dans _cross_fade),
## jamais pendant que la largeur change encore.
const CONTENT_FADE_SECONDS := 0.25

const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4
const WARNING_DIALOG := preload("res://scenes/ui/warning_dialog.tscn")

## Bubbled up à desktop.gd, qui décide ce qu'ouvrir "générer le rapport" veut
## dire.
signal generate_report_requested
## Bubbled up à desktop.gd.
signal thought_requested(text: String, translation_key: String)
## Bubbled up à desktop.gd (voir _update_report_button) — reflète l'état du
## bouton de CE panneau pour que desktop.gd puisse montrer/cacher le raccourci
## équivalent du header (DesktopHeader.set_generate_report_button_visible),
## sans dupliquer la logique de déblocage (ClueManager.has_unlocked_mission_solution)
## ailleurs.
signal report_availability_changed(available: bool)

@export var mission_id: int = 1

@onready var _background: Panel = %Background
@onready var _expand_button: Button = %ExpandButton
@onready var _retract_button: Button = %RetractButton
@onready var _title_bar: PanelContainer = %TitleBar
@onready var _title_label: Label = %TitleLabel
## Remplace _title_label une fois COLLAPSED (voir _apply_state) : le titre
## complet n'a plus la place de s'afficher correctement dans les
## COLLAPSED_VISIBLE_WIDTH px encore visibles, une flèche seule reste lisible
## et signale clairement qu'un clic rouvre le panneau.
@onready var _collapsed_arrow_label: Label = %CollapsedArrowLabel
@onready var _narrow_body: ScrollContainer = %Body
@onready var _content_list: VBoxContainer = %ContentList
@onready var _full_body: MarginContainer = %FullBody
@onready var _question_label: Label = %QuestionLabel
@onready var _clue_board: ClueBoard = %ClueBoard
@onready var _generate_report_button: Button = %GenerateReportButton

var _state: PanelState = PanelState.NARROW
var _box_tween: Tween
var _content_fade_tween: Tween

## Garde-fou pour ne déclencher qu'une fois la pensée THOUGHT_ALL_CLUES_FOUND
## (voir _on_clue_unlocked) : sans lui, une fois tous les indices de cette
## mission trouvés, chaque indice débloqué d'une AUTRE mission plus tard
## repasserait par ce même test (toujours vrai, plus rien à débloquer ici) et
## la rejouerait indéfiniment.
var _all_clues_found_thought_shown: bool = false

var _report_confirm_dialog: WarningDialog
var _report_button_blink_tween: Tween


func _ready() -> void:
	_content_list.custom_minimum_size.x = CONTENT_LIST_MIN_WIDTH
	_expand_button.pressed.connect(_on_expand_button_pressed)
	_retract_button.pressed.connect(_on_retract_button_pressed)
	_background.gui_input.connect(_on_background_gui_input)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	## Rafraîchit toute la liste/le graph d'un coup (voir
	## ClueBoard._on_all_unlocked_changed, même besoin) — outil de debug qui
	## peut débloquer/verrouiller tous les indices en une fois, pas un id précis.
	ClueManager.all_unlocked_changed.connect(_rebuild_content)
	ClueManager.all_unlocked_changed.connect(_update_report_button)

	_report_confirm_dialog = WARNING_DIALOG.instantiate()
	## Sur la racine du bureau (Desktop, plein écran), pas sur `self` : ce
	## panneau est collé au bord droit et bien plus étroit que l'écran — un
	## enfant direct s'y centrerait par rapport à SA largeur à lui, pas celle
	## de l'écran.
	##
	## call_deferred : ce _ready() s'exécute pendant que Desktop (current_scene,
	## un ancêtre de ce panneau) est encore en train d'instancier ses propres
	## enfants — un add_child() synchrone sur lui échoue alors ("Parent node is
	## busy setting up children", voir la Console). _report_confirm_dialog
	## restait de ce fait hors de l'arbre, son _ready() ne s'exécutait jamais et
	## ses @onready (ex. _message_label) restaient null, plantant plus tard sur
	## set_text() au premier clic sur "Générer le rapport".
	get_tree().current_scene.add_child.call_deferred(_report_confirm_dialog)
	_report_confirm_dialog.confirmed.connect(_on_report_confirmed)
	_generate_report_button.pressed.connect(show_generate_report_confirmation)
	_generate_report_button.gui_input.connect(_on_generate_report_button_gui_input)
	_generate_report_button.mouse_entered.connect(_on_generate_report_button_mouse_entered)
	_generate_report_button.mouse_exited.connect(_on_generate_report_button_mouse_exited)

	_rebuild_content()


## A appeler une fois par desktop.gd pour choisir la mission à afficher (même
## contrat que ClueBoard.setup) — reconstruit
## toujours liste et graph, y compris pour reprendre une sauvegarde où des
## indices sont déjà débloqués avant que ce panneau n'ait jamais reçu
## clue_unlocked.
func setup(new_mission_id: int) -> void:
	mission_id = new_mission_id
	_clue_board.setup(mission_id)
	_question_label.text = tr("CLUEBOARD_TITLE_M%d" % mission_id)
	_question_label.visible = ClueManager.has_mission_started(mission_id)
	_rebuild_content()
	_update_report_button()

	## Bureau vierge (aucun indice de cette mission encore débloqué, ex.
	## tout juste après "SE CONNECTER" sur une nouvelle partie) : rien à
	## montrer, le panneau démarre donc rétracté (niveau 0) plutôt que
	## NARROW par défaut — instant (voir _apply_state) pour ne pas montrer
	## de glissement à peine le bureau affiché. Sans effet sur une
	## sauvegarde reprise en cours d'enquête : le panneau garde alors son
	## état NARROW par défaut pour montrer les indices déjà trouvés.
	if not ClueManager.has_mission_started(mission_id):
		_apply_state(PanelState.COLLAPSED, true)


## A appeler quand un indice est cliqué ailleurs sur le bureau (voir
## desktop.gd, ClueManager.clue_clicked) — déploie le panneau en NARROW s'il
## était COLLAPSED, sans effet sinon (jamais de rétrogradation depuis FULL si
## le joueur est déjà en train de consulter le tableau d'enquête).
func expand() -> void:
	if _state == PanelState.COLLAPSED:
		_apply_state(PanelState.NARROW)


func _on_clue_unlocked(_clue_id: String) -> void:
	_rebuild_content()
	if not _question_label.visible:
		_question_label.visible = ClueManager.has_mission_started(mission_id)
	_update_report_button()

	if not _all_clues_found_thought_shown and ClueManager.has_unlocked_all_clues(mission_id):
		_all_clues_found_thought_shown = true
		thought_requested.emit(tr("THOUGHT_ALL_CLUES_FOUND"), "THOUGHT_ALL_CLUES_FOUND")


## Un indice par bulle (voir _build_clue_bubble), regroupés sous un en-tête
## par catégorie (voir _build_category_header) — même liste de catégories que
## ClueBoard (ClueManager.get_categories_for_mission, déjà filtrée aux
## catégories affichables ayant au moins un indice débloqué), donc une
## catégorie n'apparaît ici qu'une fois son premier indice découvert, comme
## sur le tableau d'enquête.
func _rebuild_content() -> void:
	for child in _content_list.get_children():
		child.queue_free()
	for categ in ClueManager.get_categories_for_mission(mission_id):
		## is_superseded_by_link : une question (voir clues_link.txt) dont la
		## réponse est déjà connue n'a plus sa place ici, la réponse répondant
		## déjà à sa place (voir ClueManager.is_superseded_by_link) — seul le
		## tableau d'enquête FULL (ClueBoard) continue de tout montrer. Si ça
		## vide entièrement une catégorie, son en-tête n'est pas affiché non
		## plus (voir `continue` ci-dessous), pour ne pas laisser un titre sans
		## aucune bulle en dessous.
		var clues: Array = ClueManager.get_clues_for_category(mission_id, categ.id).filter(
			func(clue: ClueDefinition) -> bool:
				return ClueManager.is_unlocked(clue.id) and not ClueManager.is_superseded_by_link(clue.id)
		)
		if clues.is_empty():
			continue
		_content_list.add_child(_build_category_header(categ))
		clues.sort_custom(func(a: ClueDefinition, b: ClueDefinition) -> bool: return a.date < b.date)
		for clue: ClueDefinition in clues:
			_content_list.add_child(_build_clue_bubble(clue))
	_content_list.add_child(_build_footer_hint())


func _build_category_header(categ: ClueCategory) -> Control:
	var label := Label.new()
	label.text = tr(categ.label_key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	label.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE)
	return label


## Rappel discret toujours en bas de la liste NARROW (voir _rebuild_content,
## qui le rajoute après chaque reconstruction) — texte muet (TEXT_LOCKED),
## même recette que la ligne "Communication cryptée..." de ConversationView,
## pour ne pas rivaliser visuellement avec les bulles d'indices au-dessus.
func _build_footer_hint() -> Control:
	var label := Label.new()
	label.text = tr("CLUEBOARD_PANEL_HINT")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
	label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	return label


## Même recette visuelle que ChatBubble (voir chat_bubble.gd) — fond
## Palette.BUBBLE_OTHER, coins arrondis 14px, mêmes marges et taille de
## police — plutôt qu'une instance de ChatBubble elle-même : pas de
## DialogueLine ici, un texte déjà traduit (translations/indices.csv) suffit,
## sans effet de frappe ni logique "bulle joueur à droite" (aucune notion de
## joueur/interlocuteur pour un indice collecté).
##
## Fond distinct (Palette.BUBBLE_PLAYER, même vert foncé que les SMS
## d'Alizée) quand ce clue est la solution d'une fusion déjà résolue (voir
## ClueManager.is_link_solution) — que ce soit une vraie 3e carte ou la
## réponse elle-même faisant office de solution (voir clue_fusion.gd) : dans
## les deux cas, IDClue1/IDClue2 d'origine ont déjà disparu de cette liste
## (voir _rebuild_content), seule cette bulle représente la paire résolue,
## elle mérite de ressortir.
func _build_clue_bubble(clue: ClueDefinition) -> Control:
	var is_solution := ClueManager.is_link_solution(clue.id)

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BUBBLE_PLAYER if is_solution else Palette.BUBBLE_OTHER
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", style)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	label.text = RichTextMarkup.html_to_bbcode(tr(clue.id))
	bubble.add_child(label)

	return bubble


## "→" : FULL -> NARROW, ou NARROW -> COLLAPSED — un cran de moins à chaque clic.
func _on_retract_button_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	if _state == PanelState.FULL:
		_apply_state(PanelState.NARROW)
	else:
		_apply_state(PanelState.COLLAPSED)


## "←" : NARROW -> FULL, seul cran vers le haut (COLLAPSED -> NARROW se fait
## en cliquant le fond du panneau replié, voir _on_background_gui_input, pas
## ce bouton qui n'est de toute façon pas visible tant que COLLAPSED).
func _on_expand_button_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_apply_state(PanelState.FULL)


## Seul le fond réagit au clic une fois COLLAPSED (pas tout le Control) : dans
## cet état, seuls les COLLAPSED_VISIBLE_WIDTH px de gauche du fond dépassent
## réellement à l'écran, le reste du panneau (dont les boutons) étant poussé
## hors du viewport — inutile de distinguer davantage la zone cliquable.
func _on_background_gui_input(event: InputEvent) -> void:
	if _state != PanelState.COLLAPSED:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_apply_state(PanelState.NARROW)


## position.x qu'aurait le panneau au repos (NARROW), recalculée à chaque
## appel plutôt que mise en cache — voir échange avec l'utilisateur : une
## version précédente la capturait une seule fois dans _ready() via
## `position.x`, mais ce Control est ancré au bord droit (anchor_left =
## anchor_right = 1.0, largeur pilotée par les offsets, voir
## desktop_clue_panel.tscn) et son tout premier `position.x` peut être lu
## avant que la mise en page du bureau parent ne soit stabilisée (même souci
## que ClueBoard.setup(), voir son commentaire) — une valeur fausse capturée
## une fois là contaminait ensuite indéfiniment tous les glissements
## COLLAPSED/NARROW/FULL de la session. Recalculée à partir de l'ancre plutôt
## que lue : anchor_left = anchor_right = 1.0 donne
## position.x = largeur_viewport * 1.0 + offset_left, et offset_left vaut
## toujours -EXPANDED_WIDTH au repos (voir la scène) — aucune valeur à mettre
## en cache, juste une formule fixe.
func _compute_narrow_position_x() -> float:
	return get_viewport_rect().size.x - EXPANDED_WIDTH


## Point d'entrée unique des 3 états : bascule la visibilité des éléments de
## titre propres à chaque état, échange le contenu (liste <-> graph) si on
## franchit la frontière NARROW<->FULL, puis anime position/largeur du cadre
## en un seul mouvement (voir _animate_box) — glissement simple choisi pour
## rester cohérent avec le repli existant, juste appliqué à `size` en plus de
## `position` pour les transitions qui changent réellement de largeur.
## `instant` (voir setup()) applique directement position/size finales sans
## glissement ni fondu — pour poser l'état de départ (COLLAPSED sur un bureau
## vierge) sans faire "voir" l'animation au joueur dès l'arrivée sur l'écran.
func _apply_state(new_state: PanelState, instant: bool = false) -> void:
	if new_state == _state:
		return
	var previous_state := _state
	_state = new_state

	_title_label.visible = new_state != PanelState.COLLAPSED
	_collapsed_arrow_label.visible = new_state == PanelState.COLLAPSED
	_expand_button.visible = new_state == PanelState.NARROW
	## Sans ça, RetractButton (seul enfant visible restant de Row une fois
	## TitleLabel/ExpandButton cachés ci-dessus) se retrouve repositionné par
	## le HBoxContainer tout au DÉBUT de la barre — pile là où
	## CollapsedArrowLabel est fixée — et son fond vert se superpose à la
	## flèche nue.
	_retract_button.visible = new_state != PanelState.COLLAPSED
	_background.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if new_state == PanelState.COLLAPSED else Control.CURSOR_ARROW

	if instant:
		## Ce chemin ne s'exécute qu'une fois, tout au tout début de la partie
		## (bureau vierge, voir setup()) — donc potentiellement sur une des
		## toutes premières frames après le chargement de la scène Desktop,
		## avant que get_viewport_rect() ne reflète forcément sa taille finale
		## stabilisée (même souci que ClueBoard.setup(), voir son commentaire).
		## Une largeur/position calculée sur une lecture encore transitoire ici
		## restait ensuite fausse pour le reste de la session tant qu'aucun
		## _apply_state ultérieur (ex. NARROW -> FULL -> NARROW) ne la
		## recalculait sur une frame stabilisée — voir échange avec
		## l'utilisateur (bulles/tableau tronqués uniquement avant la première
		## transition manuelle du joueur, jamais après).
		await get_tree().process_frame
		await get_tree().process_frame

	var narrow_position_x := _compute_narrow_position_x()
	var target_width := EXPANDED_WIDTH
	var target_x := narrow_position_x
	if new_state == PanelState.COLLAPSED:
		target_x = narrow_position_x + SLIDE_OFFSET
	elif new_state == PanelState.FULL:
		target_width = get_viewport_rect().size.x * FULL_WIDTH_RATIO
		## - FULL_RIGHT_MARGIN : décale tout le panneau (donc son bord droit
		## aussi) légèrement vers la gauche, pour ne jamais toucher pile le
		## bord de l'écran (voir FULL_RIGHT_MARGIN).
		target_x = narrow_position_x + EXPANDED_WIDTH - target_width - FULL_RIGHT_MARGIN

	if instant:
		## set_deferred sur la PROPRIÉTÉ ENTIÈRE ("position"/"size"), pas sur
		## un sous-chemin "position:x"/"size:x" : set_deferred() ne supporte
		## PAS la syntaxe deux-points de Tween.tween_property()/Object.set()
		## — un appel set_deferred("position:x", ...) échoue silencieusement
		## (aucune erreur, juste aucun effet), vérifié en isolation. Une
		## version précédente utilisait cette syntaxe invalide croyant
		## contourner l'avertissement moteur ("Nodes with non-equal opposite
		## anchors will have their size overridden after _ready()...") : au
		## lieu de le contourner, elle empêchait purement et simplement
		## position/size d'être appliqués du tout, laissant le panneau à
		## largeur nulle — pire que l'avertissement d'origine (voir échange
		## avec l'utilisateur, panel.size=(0.0, ...) constaté en jeu).
		set_deferred("position", Vector2(target_x, position.y))
		set_deferred("size", Vector2(target_width, size.y))
		_narrow_body.visible = new_state != PanelState.FULL
		_full_body.visible = new_state == PanelState.FULL
		return

	if new_state == PanelState.FULL:
		_cross_fade(_narrow_body, _full_body)
	elif previous_state == PanelState.FULL:
		_cross_fade(_full_body, _narrow_body)

	## TitleBar est un enfant du VBoxContainer Layout : son repositionnement/
	## redimensionnement interne (sort_children, différé par Godot à la fin de
	## la frame) accuse un léger retard sur Background, lui repositionné/
	## redimensionné directement par ancrage plein cadre dès que `size`/
	## `position` changent — pendant le glissement, la barre de titre reste
	## donc visible un instant à son ancienne largeur/position pendant que le
	## fond du panneau a déjà atteint la nouvelle, ce qui donne l'impression
	## qu'elle "ne suit pas" le cadre. Toute la barre (pas seulement le texte,
	## insuffisant : c'est son propre cadre qui accuse le retard) est cachée
	## le temps du glissement, réaffichée une fois celui-ci stabilisé.
	_title_bar.hide()
	var tween := _animate_box(target_width, target_x)
	tween.chain().tween_callback(_show_title_bar)
	if new_state == PanelState.FULL:
		## ClueBoard a été construit une seule fois (voir setup(), appelé au
		## démarrage pendant que le panneau est encore NARROW) — sans ce
		## rafraîchissement, son graph resterait calé sur cette largeur
		## étroite au lieu d'utiliser toute la largeur FULL désormais
		## disponible. Chaîné après le glissement (pas en parallèle) pour lire
		## une largeur de conteneur déjà stabilisée, pas encore en transition.
		tween.chain().tween_callback(_clue_board.refresh_layout)


## Réaffiche TitleBar une fois le glissement stabilisé (voir le commentaire
## juste au-dessus) — sa largeur est ensuite forcée explicitement plutôt que
## de compter sur le recalcul automatique de Layout (VBoxContainer) : un
## enfant masqué est exclu des calculs de mise en page tant qu'il reste
## caché (voir échange avec l'utilisateur — le fond de la barre et son trait
## du bas débordaient à gauche, uniquement ce cadre-là, jamais le corps du
## panneau qui n'a jamais été caché/réaffiché de cette façon).
func _show_title_bar() -> void:
	_title_bar.show()
	_title_bar.size.x = size.x


func _animate_box(target_width: float, target_x: float) -> Tween:
	SfxPlayer.play(SfxPlayer.UI_SLIDE_SFX)
	if is_instance_valid(_box_tween):
		_box_tween.kill()
	_box_tween = create_tween()
	_box_tween.set_ease(Tween.EASE_OUT)
	_box_tween.set_trans(Tween.TRANS_CUBIC)
	_box_tween.set_parallel(true)
	_box_tween.tween_property(self, "position:x", target_x, SLIDE_SECONDS)
	_box_tween.tween_property(self, "size:x", target_width, SLIDE_SECONDS)
	return _box_tween


## Estompe `hide_control` en tout début de glissement puis, une fois le cadre
## stabilisé à sa largeur finale (délai calé sur SLIDE_SECONDS), fait
## apparaître `show_control` en fondu — jamais les deux visibles en même temps
## pendant que le cadre est encore en train de bouger.
func _cross_fade(hide_control: Control, show_control: Control) -> void:
	if is_instance_valid(_content_fade_tween):
		_content_fade_tween.kill()
	_content_fade_tween = create_tween()
	_content_fade_tween.tween_property(hide_control, "modulate:a", 0.0, CONTENT_FADE_SECONDS)
	_content_fade_tween.tween_callback(func() -> void:
		hide_control.visible = false
		hide_control.modulate.a = 1.0
		show_control.modulate.a = 0.0
		show_control.visible = true
	)
	_content_fade_tween.tween_interval(maxf(SLIDE_SECONDS - CONTENT_FADE_SECONDS, 0.0))
	_content_fade_tween.tween_property(show_control, "modulate:a", 1.0, CONTENT_FADE_SECONDS)


## --- Bouton "Générer le rapport" (panneau FULL) ---------------------------
## Question de mission, blink une fois la résolution débloquée, confirmation
## avant de vraiment déclencher le rapport.

func _update_report_button() -> void:
	_generate_report_button.modulate = Color.WHITE
	var mission_started := ClueManager.has_mission_started(mission_id)
	_generate_report_button.visible = mission_started
	if not mission_started:
		_stop_report_button_blink()
		report_availability_changed.emit(false)
		return

	var unlocked := ClueManager.has_unlocked_mission_solution(mission_id)
	_generate_report_button.disabled = not unlocked
	_generate_report_button.theme_type_variation = &"ImportantButton" if unlocked else &"PrimaryButton"
	if unlocked:
		_start_report_button_blink()
	else:
		_stop_report_button_blink()
	report_availability_changed.emit(unlocked)


## Ouvre la confirmation "Générer le rapport" — connectée directement au
## pressed de ce panneau ci-dessus, et appelable de la même façon par son
## raccourci dans le header (voir desktop.gd, câblé sur report_availability_changed/
## DesktopHeader.generate_report_button_pressed), les deux déclenchant la
## même action. _stop_report_button_blink() ici plutôt que dans chaque
## appelant : sans ça, déclencher la confirmation depuis le header laissait le
## bouton de CE panneau continuer à clignoter derrière la boîte de dialogue.
func show_generate_report_confirmation() -> void:
	_stop_report_button_blink()
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	var white_hex := "#%s" % Palette.TEXT_NORMAL.to_html(false)
	_report_confirm_dialog.set_text(
		"[color=%s]%s[/color]\n\n%s\n\n[color=%s]%s[/color]" % [
			white_hex, tr("REPORT_CONFIRM_INTENT"),
			tr("REPORT_CONFIRM_WARNING"),
			white_hex, tr("REPORT_CONFIRM_QUESTION"),
		],
		"REPORT_CONFIRM_YES", "REPORT_CONFIRM_NO"
	)
	_report_confirm_dialog.show_centered()


func _on_report_confirmed() -> void:
	generate_report_requested.emit()


func _on_generate_report_button_gui_input(event: InputEvent) -> void:
	if not _generate_report_button.disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		thought_requested.emit(tr("CLUEBOARD_REPORT_LOCKED_THOUGHT"), "CLUEBOARD_REPORT_LOCKED_THOUGHT")


func _on_generate_report_button_mouse_entered() -> void:
	if _generate_report_button.disabled:
		_generate_report_button.modulate = Color(1.15, 1.15, 1.15, 1.0)


func _on_generate_report_button_mouse_exited() -> void:
	if _generate_report_button.disabled:
		_generate_report_button.modulate = Color.WHITE


func _start_report_button_blink() -> void:
	if is_instance_valid(_report_button_blink_tween):
		return
	_report_button_blink_tween = create_tween()
	_report_button_blink_tween.set_loops()
	_report_button_blink_tween.set_trans(Tween.TRANS_SINE)
	_report_button_blink_tween.tween_property(_generate_report_button, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	_report_button_blink_tween.tween_property(_generate_report_button, "modulate:a", 1.0, BLINK_SECONDS)


func _stop_report_button_blink() -> void:
	if is_instance_valid(_report_button_blink_tween):
		_report_button_blink_tween.kill()
	_report_button_blink_tween = null
	_generate_report_button.modulate.a = 1.0
