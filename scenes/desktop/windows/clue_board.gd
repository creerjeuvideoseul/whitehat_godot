extends Control
class_name ClueBoard
## Le "tableau d'enquête" d'une mission : un avatar par catégorie/personnage
## (150x150), et pour chacun les indices qui lui sont associés, reliés par un
## trait. Un indice verrouillé affiche un texte de substitution ; une fois
## débloqué (ClueManager.unlock, déclenché par le tag [#indice=xxx] d'une
## ligne de dialogue), son vrai texte apparaît — sans qu'il faille rouvrir la
## fenêtre. Générique : entièrement piloté par ClueManager, donc réutilisable
## tel quel pour les missions suivantes en changeant juste mission_id.

const AVATAR_SIZE := 150.0
const PANEL_WIDTH := 320.0
## How far out a clue panel can sit from its avatar, before/after
## _resolve_radius() grows it to guarantee no two panels in the same star
## overlap (see PANEL_GAP_PADDING).
const MIN_RADIUS := 90.0
const MAX_RADIUS_STEP := 900.0
## The star leaves a gap pointing "up" (270°) clear for the category label,
## instead of surrounding the avatar the full 360°.
const ARC_START_DEG := -60.0
const ARC_SWEEP_DEG := 300.0
## Forced clearance kept between two clue panels of the same star, on top of
## whatever the radius already gives them — this is the "espace entre" fix.
const PANEL_GAP_PADDING := 28.0
const CLUSTER_GUTTER := 70.0
const LABEL_HEIGHT := 26.0
const LABEL_GAP := 6.0
const TOP_PADDING := 16.0
const ROW_GUTTER := 60.0
## No more than this many category stars share a row before wrapping.
const COLS_PER_ROW := 3
const LINE_COLOR := Color(0.22, 0.87, 0.45, 0.55)

@export var mission_id: int = 1

## category_id -> avatar Control, category_id -> Array[panel PanelContainer]
var _avatars_by_category: Dictionary = {}
var _panels_by_category: Dictionary = {}
## panel Control -> clue id, pour rafraîchir son texte quand il se débloque.
var _clue_id_by_panel: Dictionary = {}


func _ready() -> void:
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	ClueManager.all_unlocked_changed.connect(_on_all_unlocked_changed)


## A appeler une fois par l'écran parent (ex. ClueBoardWindow) pour choisir
## la mission à afficher et construire le tableau. Idempotent tant que la
## mission ne change pas ; change de mission = reconstruction complète.
func setup(new_mission_id: int) -> void:
	if new_mission_id == mission_id and not _avatars_by_category.is_empty():
		return
	mission_id = new_mission_id
	for child in get_children():
		child.queue_free()
	_avatars_by_category.clear()
	_panels_by_category.clear()
	_clue_id_by_panel.clear()
	# Wait for the enclosing ScrollContainer to finish laying out so
	# _get_available_width() reads its real visible size, not a stale/zero
	# one from before this window was fully added to the tree.
	await get_tree().process_frame
	_build_board()


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
		var cluster_top_y := cursor_y + LABEL_HEIGHT + LABEL_GAP + AVATAR_SIZE * 0.5

		var x_cursor := 0.0
		var row_bottom := cursor_y
		var row_nodes: Array = []

		for categ in row_categories:
			var clues := ClueManager.get_clues_for_category(mission_id, categ.id)

			var panels: Array = []
			for clue in clues:
				panels.append(_build_clue_panel(clue.id))
			var angles := _angles_for_count(clues.size())
			var radius := _resolve_radius(panels, angles)

			var cluster_width := radius * 2.0 + PANEL_WIDTH
			var cluster_center_x := x_cursor + cluster_width * 0.5
			var avatar_center := Vector2(cluster_center_x, cluster_top_y + radius)

			var avatar := _build_avatar(categ)
			avatar.position = avatar_center - Vector2(AVATAR_SIZE, AVATAR_SIZE) * 0.5
			add_child(avatar)
			_avatars_by_category[categ.id] = avatar
			row_nodes.append(avatar)

			var label := Label.new()
			label.text = tr(categ.label_key)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
			label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
			label.position = Vector2(x_cursor, cursor_y)
			label.size = Vector2(cluster_width, LABEL_HEIGHT)
			add_child(label)
			row_nodes.append(label)

			for i in panels.size():
				var panel: PanelContainer = panels[i]
				panel.position = avatar_center + Vector2(cos(angles[i]), sin(angles[i])) * radius - panel.size * 0.5
				add_child(panel)
				row_nodes.append(panel)
				row_bottom = max(row_bottom, panel.position.y + panel.size.y)

			_panels_by_category[categ.id] = panels
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


func _angles_for_count(clue_count: int) -> Array:
	var angles: Array = []
	if clue_count <= 1:
		angles.append(deg_to_rad(90.0))
		return angles
	for i in clue_count:
		angles.append(deg_to_rad(ARC_START_DEG + i * (ARC_SWEEP_DEG / float(clue_count - 1))))
	return angles


## Grows the radius (starting from MIN_RADIUS) until none of this star's
## panels overlap each other, given their real sizes — a geometric estimate
## can't account for how tall a wrapped, unlocked clue panel ends up, so this
## checks the actual rectangles instead of trusting a formula.
func _resolve_radius(panels: Array, angles: Array) -> float:
	var radius := MIN_RADIUS
	while radius <= MAX_RADIUS_STEP:
		if not _panels_overlap_at(panels, angles, radius):
			return radius
		radius += 20.0
	return radius


func _panels_overlap_at(panels: Array, angles: Array, radius: float) -> bool:
	var rects: Array = []
	for i in panels.size():
		var panel: PanelContainer = panels[i]
		var center: Vector2 = Vector2(cos(angles[i]), sin(angles[i])) * radius
		rects.append([center - panel.size * 0.5, panel.size])

	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if _rects_overlap(rects[i][0], rects[i][1], rects[j][0], rects[j][1]):
				return true
	return false


func _rects_overlap(a_pos: Vector2, a_size: Vector2, b_pos: Vector2, b_size: Vector2) -> bool:
	var pad := Vector2(PANEL_GAP_PADDING, PANEL_GAP_PADDING) * 0.5
	var a_min: Vector2 = a_pos - pad
	var a_max: Vector2 = a_pos + a_size + pad
	return a_min.x < b_pos.x + b_size.x and a_max.x > b_pos.x and a_min.y < b_pos.y + b_size.y and a_max.y > b_pos.y


func _build_avatar(categ: ClueCategory) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(3)
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
	frame.add_child(rect)
	return frame


func _build_clue_panel(clue_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var label := Label.new()
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 28, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	panel.add_child(label)

	_clue_id_by_panel[panel] = clue_id
	_apply_panel_state(panel, label, clue_id)

	panel.size = panel.get_combined_minimum_size()
	return panel


func _apply_panel_state(panel: PanelContainer, label: Label, clue_id: String) -> void:
	var is_unlocked: bool = ClueManager.is_unlocked(clue_id)

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
		style.bg_color = Color(0.09, 0.24, 0.16, 1.0)
		style.border_color = Palette.BORDER_ACCENT
		label.add_theme_color_override("font_color", Palette.TEXT_NORMAL)
		label.text = tr(clue_id)
	else:
		style.bg_color = Color(0.1, 0.11, 0.11, 1.0)
		style.border_color = Palette.TEXT_LOCKED
		label.add_theme_color_override("font_color", Palette.TEXT_LOCKED)
		label.text = tr("CLUEBOARD_LOCKED_PLACEHOLDER")
	panel.add_theme_stylebox_override("panel", style)


func _on_clue_unlocked(clue_id: String) -> void:
	for panel: PanelContainer in _clue_id_by_panel:
		if _clue_id_by_panel[panel] != clue_id:
			continue
		_refresh_panel(panel, clue_id)


## Debug-only bulk toggle (ClueManager.unlock_all()/lock_all()) : pas d'id
## précis, donc on rafraîchit tous les panneaux déjà construits d'un coup.
func _on_all_unlocked_changed() -> void:
	for panel: PanelContainer in _clue_id_by_panel:
		_refresh_panel(panel, _clue_id_by_panel[panel])


## The locked placeholder and the real clue text are rarely the same length,
## so the panel needs to resize to fit whichever one it's showing now — and
## the connecting line, which was drawn to the old size, needs a redraw too.
func _refresh_panel(panel: PanelContainer, clue_id: String) -> void:
	var label: Label = panel.get_child(0)
	_apply_panel_state(panel, label, clue_id)
	panel.size = panel.get_combined_minimum_size()
	queue_redraw()


## Center-to-center, like pins-and-string on a corkboard — the star shape
## means a panel can be above, beside, or below its avatar, so there's no
## single fixed edge (bottom, left, ...) to anchor from like a plain column.
func _draw() -> void:
	for category_id in _avatars_by_category:
		var avatar: Control = _avatars_by_category[category_id]
		var from: Vector2 = avatar.position + avatar.size * 0.5
		for panel in _panels_by_category.get(category_id, []):
			var to: Vector2 = panel.position + panel.size * 0.5
			draw_line(from, to, LINE_COLOR, 2.0, true)
