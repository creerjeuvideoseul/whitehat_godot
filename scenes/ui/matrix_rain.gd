extends ColorRect
class_name MatrixRain
## Transition "pluie numérique" façon Matrix : une grille de colonnes de
## caractères aléatoires (police mono déjà utilisée partout dans le jeu, voir
## themes/main_theme.tres — aucun asset supplémentaire nécessaire) où une
## tête lumineuse descend suivie d'une traîne qui s'estompe, sur fond noir
## opaque. Générique et réutilisable comme TerminalConsole/PlayerThought :
## s'ajoute en plein cadre du Control cible (ex: desktop.gd l'ajoute à
## WindowLayer pour ne couvrir que le bureau central, ni le header ni le
## footer), joue seule pendant RAIN_SECONDS + FADE_OUT_SECONDS, puis émet
## `finished` et se libère — rien à gérer côté appelant à part attendre le
## signal.

signal finished

## Durée totale ~1s ("très rapide"), scindée en phase active + fondu de
## sortie pour ne pas couper net sur l'élément qui apparaît ensuite.
const RAIN_SECONDS := 0.8
const FADE_OUT_SECONDS := 0.2

const FONT_SIZE := 20
## Taille d'une cellule — plus grand que la police elle-même pour aérer la
## grille ; ajuster ces deux constantes suffit à changer la densité si
## besoin (perf ou rendu visuel).
const CELL_WIDTH := 32.0
const CELL_HEIGHT := 36.0
## Intervalle entre deux avancées de la tête de chaque colonne.
const STEP_SECONDS := 0.035
## Nombre de cellules derrière la tête qui restent visibles (dégradé), avant
## de redevenir invisibles.
const TRAIL_LENGTH := 5
const CHARSET := "01ABCDEFGHIJKLMNOPQRSTUVWXYZ$%#@&*+=<>/\\"

var _columns: Array[Dictionary] = []
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color.BLACK
	# La taille finale (ancrée sur le parent) n'est fiable qu'après un premier
	# passage de layout — même contrainte que _animate_phone_reveal dans
	# desktop.gd.
	await get_tree().process_frame
	_build_columns()
	set_process(true)


func _build_columns() -> void:
	var column_count := maxi(1, int(size.x / CELL_WIDTH))
	var row_count := maxi(1, int(size.y / CELL_HEIGHT)) + TRAIL_LENGTH

	for col in column_count:
		var cells: Array[Label] = []
		for row in row_count:
			var cell := Label.new()
			cell.position = Vector2(col * CELL_WIDTH, row * CELL_HEIGHT)
			cell.size = Vector2(CELL_WIDTH, CELL_HEIGHT)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_font_size_override("font_size", FONT_SIZE)
			cell.modulate.a = 0.0
			add_child(cell)
			cells.append(cell)

		# head négatif : décale le départ de chaque colonne pour qu'elles ne
		# tombent pas toutes en même temps (effet "pluie", pas "rideau").
		_columns.append({
			"cells": cells,
			"head": -_rng.randi_range(0, row_count),
			"timer": _rng.randf_range(0.0, STEP_SECONDS),
		})


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= RAIN_SECONDS:
		set_process(false)
		_fade_out_and_finish()
		return

	for column in _columns:
		column.timer -= delta
		if column.timer <= 0.0:
			column.timer += STEP_SECONDS
			column.head += 1
			_render_column(column)


func _render_column(column: Dictionary) -> void:
	var cells: Array = column.cells
	var head: int = column.head
	for row in cells.size():
		var distance := head - row
		var cell: Label = cells[row]
		if distance < 0 or distance > TRAIL_LENGTH:
			cell.modulate.a = 0.0
			continue

		cell.text = CHARSET[_rng.randi() % CHARSET.length()]
		cell.modulate.a = 1.0
		if distance == 0:
			cell.add_theme_color_override("font_color", Palette.TEXT_ACCENT)
		elif distance <= 2:
			cell.add_theme_color_override("font_color", Palette.BORDER_ACCENT)
		else:
			cell.add_theme_color_override("font_color", Palette.TEXT_GREEN_DIM)


func _fade_out_and_finish() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	await tween.finished
	finished.emit()
	queue_free()
