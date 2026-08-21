extends Control
class_name ClueSpotlight
## Encart centré à l'écran, affiché au clic sur un passage color=indice (voir
## desktop.gd, ClueManager.clue_clicked) : montre le texte complet de
## l'indice, reste 2s, puis s'envole vers la droite (flash + translation +
## fondu) en direction du panneau latéral Collecte d'indices (DesktopCluePanel,
## que desktop.gd déploie au même moment). Même famille visuelle que le
## bandeau de desktop_header.gd::_build_toast (fond WINDOW_HEADER_BG, bordure
## BORDER_ACCENT), mais centré et réservé au texte complet d'UN indice précis
## plutôt qu'au message générique de découverte.
##
## Instance unique réutilisée par desktop.gd (comme ClueBoardTooltip/le
## toast existant) plutôt que recréée à chaque clic — un nouveau clic pendant
## que l'encart précédent est encore visible interrompt sa séquence en cours
## et relance immédiatement avec le nouveau texte.

const FADE_IN_SECONDS := 0.3
const HOLD_SECONDS := 2.0
const FLASH_SECONDS := 0.15
const FLY_SECONDS := 0.5
const FLASH_MODULATE := Color(1.5, 1.5, 1.3, 1.0)
const FLY_SCALE := Vector2(0.3, 0.3)
## Durée totale de la séquence show_clue (apparition + palier + flash + envol)
## — exposée pour que desktop.gd puisse retarder l'ouverture du panneau
## latéral Collecte d'indices jusqu'à ce que l'indice ait fini de "s'envoler"
## vers lui, plutôt que les deux animations se chevauchent.
const TOTAL_SEQUENCE_SECONDS := FADE_IN_SECONDS + HOLD_SECONDS + FLASH_SECONDS + FLY_SECONDS

@onready var _box: PanelContainer = %Box
@onready var _label: RichTextLabel = %Label

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	hide()


## Affiche le texte complet de `clue_id` (même appel que
## ClueBoard._apply_panel_state pour le texte intégral d'un indice) puis joue
## la séquence apparition/palier/envol.
func show_clue(clue_id: String) -> void:
	if is_instance_valid(_tween):
		_tween.kill()

	_label.text = RichTextMarkup.html_to_bbcode(tr(clue_id))
	scale = Vector2.ONE
	modulate = Color.WHITE
	modulate.a = 0.0
	show()

	## Attend que la taille réelle du contenu (texte fraîchement posé) soit
	## stable avant de centrer — même recette que ClueBoardTooltip._resize_to_content.
	await get_tree().process_frame
	await get_tree().process_frame
	var box_size: Vector2 = _box.get_combined_minimum_size()
	size = box_size
	pivot_offset = box_size / 2.0
	position = (get_viewport_rect().size - box_size) / 2.0

	var target_x: float = get_viewport_rect().size.x + box_size.x
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate", FLASH_MODULATE, FLASH_SECONDS)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:x", target_x, FLY_SECONDS)
	_tween.tween_property(self, "scale", FLY_SCALE, FLY_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FLY_SECONDS)
	_tween.chain().tween_callback(hide)
