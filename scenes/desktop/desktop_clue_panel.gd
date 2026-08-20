extends Control
class_name DesktopCluePanel
## Panneau permanent ancré au bord droit de l'écran (voir desktop.tscn) —
## distinct des fenêtres de WindowLayer (ChatWindow, ClueBoardWindow...) :
## jamais réduit dans la barre des tâches, toujours présent, seulement
## rétractable sur lui-même. Bordure/coins droits volontairement absents
## (voir StyleBoxFlat_bg/StyleBoxFlat_border_overlay dans la scène,
## border_width_right = 0 et corner_radius_*_right = 0) : le panneau est
## censé se fondre dans le bord de l'écran auquel il est collé plutôt que de
## paraître flotter devant.
##
## Contenu central rempli au fil des indices débloqués (voir _rebuild_content) :
## un indice = une "bulle", même recette visuelle que ChatBubble (voir
## chat_bubble.gd) plutôt qu'une nouvelle instanciée de la scène (pas de
## DialogueLine ici, un texte déjà traduit suffit, sans effet de frappe ni
## bulle "joueur" à droite). Regroupés par catégorie (IdCategUnique, même
## découpage que ClueBoard) puis triés par ClueDate — la date de l'indice
## lui-même, pas sa date de découverte — à l'intérieur de chaque catégorie.
## clues_link.txt (fusion d'indices liés) n'est volontairement pas pris en
## compte ici, chantier séparé à venir.

## Largeur du panneau déployé — 400 + les ~118px regagnés en réduisant la
## largeur du téléphone d'Alizée (voir alizee_phone.tscn, offset_right), + 20px
## de plus (deux fois 10px) pour absorber l'espace libéré par les décalages
## successifs à gauche de PhoneSectionHost (voir desktop.tscn) et garder
## inchangé l'écart entre la fenêtre SMS/Mail/Galerie/Coffre et ce panneau.
const EXPANDED_WIDTH := 538.23
## Largeur qui reste visible une fois rétracté (le reste glisse hors écran,
## le panneau étant déjà collé au bord droit) — juste assez pour rester
## repérable et cliquable, sans prendre de place inutile sur le bureau.
const COLLAPSED_VISIBLE_WIDTH := 30.0
const SLIDE_OFFSET := EXPANDED_WIDTH - COLLAPSED_VISIBLE_WIDTH
const SLIDE_SECONDS := 0.4

@export var mission_id: int = 1

@onready var _background: Panel = %Background
@onready var _retract_button: Button = %RetractButton
@onready var _content_list: VBoxContainer = %ContentList
@onready var _title_label: Label = %TitleLabel
## Remplace _title_label une fois rétracté (voir _set_collapsed) : le titre
## complet n'a plus la place de s'afficher correctement dans les
## COLLAPSED_VISIBLE_WIDTH px encore visibles, une flèche seule reste lisible
## et signale clairement qu'un clic rouvre le panneau.
@onready var _collapsed_arrow_label: Label = %CollapsedArrowLabel

var _collapsed: bool = false
var _slide_tween: Tween
## position.x réel du panneau déployé, capturé au démarrage — voir
## _set_collapsed. Ce n'est PAS 0 : le panneau est ancré au bord droit
## (anchor_left = anchor_right = 1.0), donc Godot calcule
## position.x = anchor_left * largeur_parent + offset_left, une valeur bien
## plus grande que 0. Animer vers 0.0 en dur (comme dans une première version
## de ce script) faisait sauter le panneau vers la gauche de l'écran au lieu
## de le glisser légèrement vers la droite.
var _expanded_position_x: float


func _ready() -> void:
	_expanded_position_x = position.x
	_retract_button.pressed.connect(_on_retract_button_pressed)
	_background.gui_input.connect(_on_background_gui_input)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	## Rafraîchit toute la liste d'un coup (voir ClueBoard._on_all_unlocked_changed,
	## même besoin) — outil de debug qui peut débloquer/verrouiller tous les
	## indices en une fois, pas un id précis à ajouter/retirer.
	ClueManager.all_unlocked_changed.connect(_rebuild_content)
	_rebuild_content()


## A appeler une fois par desktop.gd pour choisir la mission à afficher (même
## contrat que ClueBoard.setup, voir clue_board.gd) — reconstruit toujours la
## liste, y compris pour reprendre une sauvegarde où des indices sont déjà
## débloqués avant que ce panneau n'ait jamais reçu clue_unlocked.
func setup(new_mission_id: int) -> void:
	mission_id = new_mission_id
	_rebuild_content()


## A appeler quand un indice est cliqué ailleurs sur le bureau (voir
## desktop.gd, ClueManager.clue_clicked) — redéploie le panneau s'il était
## replié, sans effet sinon (idempotent, comme _set_collapsed lui-même).
func expand() -> void:
	_set_collapsed(false)


func _on_clue_unlocked(_clue_id: String) -> void:
	_rebuild_content()


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
		_content_list.add_child(_build_category_header(categ))
		var clues: Array = ClueManager.get_clues_for_category(mission_id, categ.id).filter(
			func(clue: ClueDefinition) -> bool: return ClueManager.is_unlocked(clue.id)
		)
		clues.sort_custom(func(a: ClueDefinition, b: ClueDefinition) -> bool: return a.date < b.date)
		for clue: ClueDefinition in clues:
			_content_list.add_child(_build_clue_bubble(clue))


func _build_category_header(categ: ClueCategory) -> Control:
	var label := Label.new()
	label.text = tr(categ.label_key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
	label.add_theme_font_size_override("font_size", Palette.SIZE_SUBTITLE)
	return label


## Même recette visuelle que ChatBubble (voir chat_bubble.gd) — fond
## Palette.BUBBLE_OTHER, coins arrondis 14px, mêmes marges et taille de
## police — plutôt qu'une instance de ChatBubble elle-même : pas de
## DialogueLine ici, un texte déjà traduit (translations/indices.csv) suffit,
## sans effet de frappe ni logique "bulle joueur à droite" (aucune notion de
## joueur/interlocuteur pour un indice collecté).
func _build_clue_bubble(clue: ClueDefinition) -> Control:
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BUBBLE_OTHER
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


func _on_retract_button_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_set_collapsed(true)


## Seul le fond réagit au clic une fois rétracté (pas tout le Control) : dans
## cet état, seuls les COLLAPSED_VISIBLE_WIDTH px de gauche du fond dépassent
## réellement à l'écran, le reste du panneau (dont RetractButton) étant
## poussé hors du viewport — inutile de distinguer davantage la zone cliquable.
func _on_background_gui_input(event: InputEvent) -> void:
	if not _collapsed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
		_set_collapsed(false)


## Glissement horizontal relatif à _expanded_position_x — même recette que
## desktop.gd::_minimize_window_with_slide (capturer la position d'origine,
## animer vers origine + décalage, jamais une valeur absolue en dur) pour
## rester visuellement cohérent avec les autres glissements du bureau.
func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_title_label.visible = not collapsed
	_collapsed_arrow_label.visible = collapsed
	# Main seulement quand le fond est réellement cliquable (replié, voir
	# _on_background_gui_input) — flèche curseur normale une fois déployé, le
	# fond n'ayant alors plus d'action propre.
	_background.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if collapsed else Control.CURSOR_ARROW
	if is_instance_valid(_slide_tween):
		_slide_tween.kill()
	var target_x := _expanded_position_x + (SLIDE_OFFSET if collapsed else 0.0)
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position:x", target_x, SLIDE_SECONDS)
