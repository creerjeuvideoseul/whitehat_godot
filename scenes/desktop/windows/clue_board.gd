extends Control
class_name ClueBoard
## Le "tableau d'enquête" d'une mission : un avatar par catégorie/personnage
## (voir AVATAR_SIZE) en haut d'une colonne, avec sous lui un trait vertical ("tronc")
## qui descend jusqu'au dernier indice de cette catégorie ; chaque indice est
## relié à ce tronc par un trait horizontal perpendiculaire, façon
## organigramme (un indice = une ligne). Un indice verrouillé affiche un
## texte de substitution ; une fois débloqué (ClueManager.unlock, déclenché
## par le tag [#indice=xxx] d'une ligne de dialogue), son vrai texte apparaît
## — sans qu'il faille rouvrir la fenêtre. Générique : entièrement piloté par
## ClueManager, donc réutilisable tel quel pour les missions suivantes en
## changeant juste mission_id.

const AVATAR_SIZE := 190.0
## Partagée avec le shader (border_width_px) pour que le clip circulaire de
## l'image s'arrête juste avant la bordure au lieu de la recouvrir — sinon
## une image zoomée (voir IMAGE_ZOOM) atteint le même rayon que l'anneau et
## le fait disparaître dessous.
const AVATAR_BORDER_WIDTH := 3.0
## Cadrage de la photo à l'intérieur du cercle (voir circular_mask.gdshader)
## — rapproche le portrait sans agrandir l'anneau lui-même.
const IMAGE_ZOOM := 1.15
const CATEGORY_LABEL_FONT_SIZE := Palette.SIZE_BODY + 5
const CIRCULAR_MASK_SHADER := preload("res://assets/shaders/circular_mask.gdshader")
const PANEL_WIDTH := 420.0
## Longueur du trait horizontal entre le tronc et le panneau d'un indice.
const BRANCH_LENGTH := 40.0
## Espace vertical entre le bas de l'avatar et le centre du premier indice —
## laisse un bout de tronc visible avant la première branche.
const FIRST_BRANCH_GAP := 30.0
## Espace vertical entre deux panneaux d'indices empilés dans la même colonne.
const CLUE_VERTICAL_GAP := 20.0
const CLUSTER_GUTTER := 70.0
## Un peu plus que CATEGORY_LABEL_FONT_SIZE pour laisser de la place au texte.
const LABEL_HEIGHT := 32.0
const LABEL_GAP := 15.0
const TOP_PADDING := 16.0
const ROW_GUTTER := 60.0
## No more than this many category columns share a row before wrapping.
const COLS_PER_ROW := 3
const LINE_COLOR := Color(Palette.BORDER_ACCENT, 0.55)

@export var mission_id: int = 1

## category_id -> avatar Control, category_id -> Array[panel PanelContainer]
var _avatars_by_category: Dictionary = {}
var _panels_by_category: Dictionary = {}


func _ready() -> void:
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	ClueManager.all_unlocked_changed.connect(_on_all_unlocked_changed)


## A appeler une fois par l'écran parent (ex. DesktopCluePanel) pour choisir
## la mission à afficher et construire le tableau. Idempotent tant que la
## mission ne change pas ; change de mission = reconstruction complète.
func setup(new_mission_id: int) -> void:
	if new_mission_id == mission_id and not _avatars_by_category.is_empty():
		return
	mission_id = new_mission_id
	_clear_board()
	# Wait for the enclosing ScrollContainer to finish laying out so
	# _get_available_width() reads its real visible size, not a stale/zero
	# one from before this window was fully added to the tree.
	await get_tree().process_frame
	_build_board()


func _clear_board() -> void:
	for child in get_children():
		child.queue_free()
	_avatars_by_category.clear()
	_panels_by_category.clear()


## Reconstruction immédiate (sans attendre de frame, contrairement à setup())
## : le ScrollContainer est déjà dimensionné puisque le tableau était déjà à
## l'écran — utilisé quand un indice fraîchement débloqué révèle une
## catégorie pas encore affichée (voir _on_clue_unlocked) ou que le debug
## unlock_all/lock_all change potentiellement tout le jeu de catégories
## visibles d'un coup.
func _rebuild_board_now() -> void:
	_clear_board()
	_build_board()


## A appeler après un redimensionnement externe du conteneur (ex. le panneau
## Collecte d'indices qui passe de sa largeur étroite à sa largeur pleine,
## voir desktop_clue_panel.gd) — setup() seul ne suffit pas ici : son
## garde-fou "même mission déjà construite" (voir ci-dessus) empêcherait de
## relire la nouvelle largeur disponible via _get_available_width().
func refresh_layout() -> void:
	_rebuild_board_now()


func _build_board() -> void:
	var categories := ClueManager.get_categories_for_mission(mission_id)
	if categories.is_empty():
		return

	var viewport_width: float = _get_available_width()
	var overall_width := 0.0
	var cursor_y := TOP_PADDING
	# One entry per row: the nodes it contains and how wide it ended up, so
	# they can all be re-centered once every row's real width is known.
	var rows: Array = []

	var row_start := 0
	while row_start < categories.size():
		var row_categories: Array = categories.slice(row_start, min(row_start + COLS_PER_ROW, categories.size()))
		var avatar_top_y := cursor_y + LABEL_HEIGHT + LABEL_GAP

		var x_cursor := 0.0
		var row_bottom := cursor_y
		var row_nodes: Array = []

		for categ in row_categories:
			var clues := ClueManager.get_clues_for_category(mission_id, categ.id)
			var cluster_width: float = AVATAR_SIZE * 0.5 + BRANCH_LENGTH + PANEL_WIDTH

			var avatar := _build_avatar(categ)
			avatar.position = Vector2(x_cursor, avatar_top_y)
			add_child(avatar)
			_avatars_by_category[categ.id] = avatar
			row_nodes.append(avatar)

			var label := Label.new()
			label.text = tr(categ.label_key)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
			label.add_theme_font_size_override("font_size", CATEGORY_LABEL_FONT_SIZE)
			label.position = Vector2(x_cursor, cursor_y)
			label.size = Vector2(AVATAR_SIZE, LABEL_HEIGHT)
			add_child(label)
			row_nodes.append(label)

			# Le tronc part du centre de l'avatar ; chaque indice est empilé
			# sous le précédent, dans la même colonne, décalé à droite du
			# tronc d'une "branche" horizontale fixe.
			var panel_x: float = x_cursor + AVATAR_SIZE * 0.5 + BRANCH_LENGTH
			var next_top: float = avatar_top_y + AVATAR_SIZE + FIRST_BRANCH_GAP

			var panels: Array = []
			for clue in clues:
				var panel := _build_clue_panel(clue.id)
				panel.position = Vector2(panel_x, next_top)
				add_child(panel)
				panels.append(panel)
				row_nodes.append(panel)
				row_bottom = max(row_bottom, panel.position.y + panel.size.y)
				next_top += panel.size.y + CLUE_VERTICAL_GAP

			_panels_by_category[categ.id] = panels
			row_bottom = max(row_bottom, avatar_top_y + AVATAR_SIZE)
			x_cursor += cluster_width + CLUSTER_GUTTER

		var row_width: float = x_cursor - CLUSTER_GUTTER
		overall_width = max(overall_width, row_width)
		rows.append({"nodes": row_nodes, "width": row_width})

		cursor_y = row_bottom + ROW_GUTTER
		row_start += COLS_PER_ROW

	# Center each row on the widest one, then center that against the
	# viewport if the whole board is narrower than the window.
	var viewport_offset: float = max((viewport_width - overall_width) * 0.5, 0.0)
	for row in rows:
		var row_offset: float = viewport_offset + max((overall_width - row.width) * 0.5, 0.0)
		if row_offset > 0.0:
			for node in row.nodes:
				node.position.x += row_offset

	custom_minimum_size = Vector2(max(overall_width, viewport_width), cursor_y)
	queue_redraw()


## The board sits inside a ScrollContainer — its size at this point reflects
## the actual visible area (BoardScroll has already been laid out by the
## time setup() awaits a frame before calling this). Falls back to a sane
## default if read too early (e.g. off-tree during a test).
func _get_available_width() -> float:
	var parent := get_parent()
	if parent is Control and parent.size.x > 0.0:
		return parent.size.x
	return 2000.0


func _build_avatar(categ: ClueCategory) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(int(AVATAR_BORDER_WIDTH))
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(int(AVATAR_SIZE / 2))
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)

	var texture: Texture2D = load(categ.image_path) if ResourceLoader.exists(categ.image_path) else null
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	## L'anneau vert ne découpe rien tout seul (voir StyleBoxFlat plus haut,
	## purement décoratif) — sans ce shader, une image source pas
	## parfaitement pré-détourée en cercle (bord anti-aliasé, coin oublié...)
	## dépasse visuellement de l'anneau. Le shader garantit un cercle net
	## quelle que soit la propreté de l'image, plutôt que de dépendre de
	## chaque asset préparé à la main pour chaque future mission.
	var mask := ShaderMaterial.new()
	mask.shader = CIRCULAR_MASK_SHADER
	mask.set_shader_parameter("zoom", IMAGE_ZOOM)
	mask.set_shader_parameter("avatar_size", AVATAR_SIZE)
	mask.set_shader_parameter("border_width_px", AVATAR_BORDER_WIDTH)
	rect.material = mask
	frame.add_child(rect)
	return frame


func _build_clue_panel(clue_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	## RichTextLabel, pas Label : le texte d'un indice peut porter <color=important>
	## (voir translations/indices.csv), résolu via RichTextMarkup.html_to_bbcode
	## comme partout ailleurs où du texte de donnée brute s'affiche (mail/SMS/
	## galerie/OSINT).
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 28, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", Palette.SIZE_SMALL)
	panel.add_child(label)

	_apply_panel_state(panel, label, clue_id)

	panel.size = panel.get_combined_minimum_size()
	return panel


func _apply_panel_state(panel: PanelContainer, label: RichTextLabel, clue_id: String) -> void:
	var is_unlocked: bool = ClueManager.is_unlocked(clue_id)
	## Les indices "de résolution" (catégories FIN/FINSECONDAIRE) se
	## distinguent en bleu une fois débloqués plutôt que le vert habituel —
	## signale que ce sont les indices qui concluent l'enquête (voir
	## Palette.CLUE_SOLUTION_*).
	var is_solution := ClueManager.get_category_id_for_clue(clue_id).begins_with(ClueManager.SOLUTION_CATEGORY_ID)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	# Fully opaque on purpose — a translucent panel let the connecting line to
	# a node further back show right through it, which read as a rendering
	# glitch rather than "this clue is behind that one".
	if is_unlocked:
		style.bg_color = Palette.CLUE_SOLUTION_BG if is_solution else Color(0.09, 0.24, 0.16, 1.0)
		style.border_color = Palette.CLUE_SOLUTION_BORDER if is_solution else Palette.BORDER_ACCENT
		label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
		label.text = RichTextMarkup.html_to_bbcode(tr(clue_id))
	else:
		style.bg_color = Color(0.1, 0.11, 0.11, 1.0)
		style.border_color = Palette.TEXT_LOCKED
		label.add_theme_color_override("default_color", Palette.TEXT_LOCKED)
		label.text = tr("CLUEBOARD_LOCKED_PLACEHOLDER")
	panel.add_theme_stylebox_override("panel", style)


## Un indice qui débloque la toute première entrée d'une catégorie révèle
## cette catégorie (nouvel avatar, nouvelle colonne) ; un indice qui débloque
## dans une catégorie déjà affichée peut aussi faire grandir son panneau (le
## texte verrouillé et le texte réel n'ont presque jamais la même hauteur).
## Reconstruction complète dans les deux cas plutôt qu'un rafraîchissement
## ciblé du seul panneau concerné : un panneau qui grandit doit repousser vers
## le bas non seulement ses voisins de colonne mais aussi les lignes de
## catégories suivantes (voir COLS_PER_ROW/ROW_GUTTER) — un simple décalage
## local les laissait chevauchées, puisque leur position avait déjà été figée
## à la construction initiale.
func _on_clue_unlocked(_clue_id: String) -> void:
	_rebuild_board_now()


## Debug-only bulk toggle (ClueManager.unlock_all()/lock_all()) : peut faire
## apparaître ou disparaître des catégories entières d'un coup, donc
## reconstruction complète plutôt qu'un simple rafraîchissement des panneaux
## déjà là.
func _on_all_unlocked_changed() -> void:
	_rebuild_board_now()


## Un tronc vertical par catégorie, du bas de l'avatar jusqu'au dernier
## indice, avec une branche horizontale perpendiculaire vers chaque panneau
## — façon organigramme, un indice = une ligne.
func _draw() -> void:
	for category_id in _avatars_by_category:
		var avatar: Control = _avatars_by_category[category_id]
		var panels: Array = _panels_by_category.get(category_id, [])
		if panels.is_empty():
			continue

		var trunk_x: float = avatar.position.x + avatar.size.x * 0.5
		var trunk_top: float = avatar.position.y + avatar.size.y
		var trunk_bottom: float = trunk_top

		for panel in panels:
			var center_y: float = panel.position.y + panel.size.y * 0.5
			trunk_bottom = max(trunk_bottom, center_y)
			draw_line(Vector2(trunk_x, center_y), Vector2(panel.position.x, center_y), LINE_COLOR, 2.0, true)

		draw_line(Vector2(trunk_x, trunk_top), Vector2(trunk_x, trunk_bottom), LINE_COLOR, 2.0, true)
