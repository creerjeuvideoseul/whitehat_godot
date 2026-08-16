extends Control
class_name DesktopHeader
## The desktop's top bar: OSINT search entry point (left) and system status
## readouts (right) — TOR indicator, CPU/MEM gauges, current pseudo. Always
## on screen in desktop.tscn; future windows (chat/phone/mail/...) render
## below it, never over it.

const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4

## Retour visuel de découverte d'indice (en plus du son, voir SfxPlayer qui
## écoute le même ClueManager.clue_unlocked) : (A) le bouton "pulse", (B) un
## badge compteur s'y accroche tant qu'on n'a pas rouvert la fenêtre, (D) un
## bandeau annonce le texte de l'indice puis disparaît.
## Même délai que SfxPlayer avant de déclencher pulse/badge/bandeau — les deux
## doivent rester synchronisés puisqu'ils réagissent au même instant perçu
## par le joueur (voir sfx_player.gd::CLUE_REVEAL_DELAY_SECONDS).
const CLUE_REVEAL_DELAY_SECONDS := 3.0
const CLUE_PULSE_SECONDS := 0.2
const CLUE_PULSE_SCALE := Vector2(1.15, 1.15)
const TOAST_WIDTH := 470.0
const TOAST_TOP_OFFSET := 100.0
const TOAST_FADE_SECONDS := 0.3
const TOAST_HOLD_SECONDS := 3.0

## Fourchette simulée pendant qu'une fenêtre système tourne (terminal, écran
## "chargement des données") — voir set_system_load_spike().
const CPU_SPIKE_MIN_PERCENT := 80.0
const CPU_SPIKE_MAX_PERCENT := 100.0

## Bubbled up so the owning scene (desktop.gd) decides what opening "Indice"
## actually means (which mission, which window) — this header doesn't know.
signal clue_button_pressed
## Bubbled up with the raw (untrimmed) query text — desktop.gd owns what
## "searching" actually opens/updates, this header only knows about the field.
signal osint_search_requested(query: String)

@onready var _tor_icon: TextureRect = %TorIcon
@onready var _pseudo_label: Label = %PseudoLabel
@onready var _clue_button: Button = %ClueButton
@onready var _search_field: LineEdit = %SearchField
@onready var _search_button: Button = %SearchButton
@onready var _cpu_gauge: UsageGauge = %CpuGauge

## (B) Badge compteur — construit en code plutôt que dans la .tscn, un simple
## indicateur ne mérite pas un noeud dédié dans la scène.
var _clue_badge: PanelContainer
var _clue_badge_label: Label
var _unseen_clue_count: int = 0

var _pulse_tween: Tween

## Clignotement (voir _start_tor_blink pour le même recette) du bouton
## Indice une fois la résolution de la mission débloquée — s'arrête dès la
## première ouverture de la fenêtre (voir _on_clue_button_pressed), mais le
## bleu (ImportantButton) reste acquis pour de bon.
var _clue_button_blink_tween: Tween

## (D) Bandeau réutilisé pour chaque notification, avec une file d'attente :
## plusieurs indices peuvent se débloquer dans la même frame (ex. les deux
## mots de passe OSINT), ils s'affichent l'un après l'autre plutôt que de se
## chevaucher.
var _toast: PanelContainer
var _toast_label: RichTextLabel
var _toast_queue: Array[String] = []
var _toast_showing: bool = false


func _ready() -> void:
	_pseudo_label.text = "%s@whos:~" % PlayerSession.pseudo
	_clue_button.pressed.connect(_on_clue_button_pressed)
	_search_button.pressed.connect(_on_search_requested)
	_search_field.text_submitted.connect(func(_text: String) -> void: _on_search_requested())
	_start_tor_blink()
	_build_clue_badge()
	_build_toast()
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)


func _on_clue_button_pressed() -> void:
	clue_button_pressed.emit()
	_unseen_clue_count = 0
	_update_clue_badge()
	_stop_clue_button_blink()


## Un seul point d'écoute pour les 3 effets déjà en place — le son suit déjà
## indépendamment via SfxPlayer sur ce même signal, avec le même délai. (E)
## s'y ajoute : passage en bouton "important" bleu si l'indice qui vient de
## se débloquer est LA résolution de mission (voir ClueManager.is_solution_clue).
func _on_clue_unlocked(clue_id: String) -> void:
	await get_tree().create_timer(CLUE_REVEAL_DELAY_SECONDS).timeout
	_pulse_clue_button()
	_unseen_clue_count += 1
	_update_clue_badge()
	_queue_toast(clue_id)
	if ClueManager.is_solution_clue(clue_id):
		_apply_solution_unlocked_state()


## A appeler une fois par desktop.gd juste après la construction du header,
## pour couvrir la reprise d'une sauvegarde où la résolution était déjà
## débloquée lors d'une session précédente. Clignote quand même : rien ne
## persiste "le joueur a déjà ouvert la fenêtre Indice depuis", donc tant que
## le bouton n'a pas encore été cliqué (ce qui arrête le clignotement, voir
## _on_clue_button_pressed) il doit continuer d'attirer l'oeil, y compris
## après un rechargement de session. Le header ne connaît pas lui-même le
## mission_id courant (voir desktop.gd::CURRENT_MISSION_ID) donc ne peut pas
## faire cette vérification seul.
func apply_resumed_clue_state(solution_already_unlocked: bool) -> void:
	if solution_already_unlocked:
		_apply_solution_unlocked_state()


func _apply_solution_unlocked_state() -> void:
	_clue_button.theme_type_variation = &"ImportantButton"
	_start_clue_button_blink()


func _pulse_clue_button() -> void:
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_clue_button.pivot_offset = _clue_button.size / 2.0
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK)
	_pulse_tween.tween_property(_clue_button, "scale", CLUE_PULSE_SCALE, CLUE_PULSE_SECONDS)
	_pulse_tween.tween_property(_clue_button, "scale", Vector2.ONE, CLUE_PULSE_SECONDS)


func _build_clue_badge() -> void:
	_clue_badge = PanelContainer.new()
	_clue_badge.custom_minimum_size = Vector2(26, 26)
	_clue_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Ancré au coin haut-droit du bouton lui-même — un Button ne "layout" pas
	## ses enfants comme un Container, on peut donc en poser un par-dessus
	## librement (même principe d'overlay que la bordure de survol des
	## vignettes de la galerie, voir gallery_section.gd).
	_clue_badge.anchor_left = 1.0
	_clue_badge.anchor_right = 1.0
	_clue_badge.offset_left = -16.0
	_clue_badge.offset_right = 10.0
	_clue_badge.offset_top = -10.0
	_clue_badge.offset_bottom = 16.0
	_clue_badge.hide()

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.TEXT_ACCENT
	style.set_corner_radius_all(13)
	style.content_margin_left = 4
	style.content_margin_right = 4
	_clue_badge.add_theme_stylebox_override("panel", style)

	_clue_badge_label = Label.new()
	_clue_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clue_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clue_badge_label.add_theme_color_override("font_color", Palette.WINDOW_BG)
	_clue_badge_label.add_theme_font_size_override("font_size", Palette.SIZE_SMALL)
	_clue_badge.add_child(_clue_badge_label)

	_clue_button.add_child(_clue_badge)


func _update_clue_badge() -> void:
	_clue_badge_label.text = str(_unseen_clue_count)
	_clue_badge.visible = _unseen_clue_count > 0


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.custom_minimum_size = Vector2(TOAST_WIDTH, 0)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.WINDOW_HEADER_BG
	style.set_border_width_all(2)
	style.border_color = Palette.BORDER_ACCENT
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_toast.add_theme_stylebox_override("panel", style)

	## RichTextLabel pour fit_content/autowrap comme le reste des labels
	## construits en code ici — le texte affiché est désormais toujours le même
	## message générique (voir _advance_toast_queue), plus besoin d'interpréter
	## de balises comme avant.
	_toast_label = RichTextLabel.new()
	_toast_label.bbcode_enabled = true
	_toast_label.fit_content = true
	_toast_label.scroll_active = false
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_color_override("default_color", Palette.TEXT_NORMAL)
	_toast_label.add_theme_font_size_override("normal_font_size", Palette.SIZE_BODY)
	_toast.add_child(_toast_label)

	add_child(_toast)


func _queue_toast(clue_id: String) -> void:
	_toast_queue.append(clue_id)
	if not _toast_showing:
		_advance_toast_queue()


func _advance_toast_queue() -> void:
	if _toast_queue.is_empty():
		_toast_showing = false
		return
	_toast_showing = true

	## Texte générique plutôt que celui de l'indice lui-même (comme sur le
	## tableau d'enquête, ClueBoard) : le joueur n'a de toute façon pas le
	## temps de le lire avant que le bandeau ne disparaisse. `clue_id` ne sert
	## donc plus qu'à savoir qu'une notification est en attente.
	_toast_queue.pop_front()
	_toast_label.text = tr("CLUE_UNLOCKED_TOAST")
	## Aligné à gauche sous le bouton "COLLECTE D'INDICE" — _clue_button est
	## niché dans Margin/Row/LeftGroup, pas un enfant direct du header, donc
	## converti en position locale à la main (Control n'a pas de to_local(),
	## contrairement à Node2D) — sous le header lui-même via TOAST_TOP_OFFSET.
	var clue_button_left: float = _clue_button.get_global_rect().position.x - get_global_rect().position.x
	_toast.position = Vector2(clue_button_left, TOAST_TOP_OFFSET)
	_toast.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, TOAST_FADE_SECONDS)
	tween.tween_interval(TOAST_HOLD_SECONDS)
	tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_SECONDS)
	tween.tween_callback(_advance_toast_queue)


## Pic de charge simulé pendant qu'une fenêtre système tourne (terminal après
## Jean Ranoud, écran "chargement des données") — voir desktop.gd, qui
## bascule ceci à l'ouverture/fermeture de ces écrans. true : jauge CPU sur
## CPU_SPIKE_MIN_PERCENT..MAX_PERCENT ; false : revient à sa fourchette
## normale (celle configurée sur CpuGauge dans la scène).
func set_system_load_spike(active: bool) -> void:
	if active:
		_cpu_gauge.set_spike_range(CPU_SPIKE_MIN_PERCENT, CPU_SPIKE_MAX_PERCENT)
	else:
		_cpu_gauge.restore_normal_range()


## Rectangle global de la barre de recherche OSINT — pour desktop.gd, qui doit
## positionner la bulle d'aide "Collecte d'indices" juste en dessous (voir
## ClueBoardTooltip.point_at). Control expose déjà get_global_rect() nativement ;
## ce n'est qu'un raccourci pour ne pas exposer _search_field lui-même à un
## autre script.
func get_search_field_global_rect() -> Rect2:
	return _search_field.get_global_rect()


func _on_search_requested() -> void:
	var query := _search_field.text.strip_edges()
	if query.is_empty():
		return
	osint_search_requested.emit(query)


func _start_tor_blink() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_tor_icon, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	tween.tween_property(_tor_icon, "modulate:a", 1.0, BLINK_SECONDS)


## Même recette que _start_tor_blink, sur _clue_button.modulate:a — arrêtée
## dès la première ouverture de la fenêtre Indice (voir _on_clue_button_pressed).
func _start_clue_button_blink() -> void:
	if is_instance_valid(_clue_button_blink_tween):
		_clue_button_blink_tween.kill()
	_clue_button_blink_tween = create_tween()
	_clue_button_blink_tween.set_loops()
	_clue_button_blink_tween.set_trans(Tween.TRANS_SINE)
	_clue_button_blink_tween.tween_property(_clue_button, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	_clue_button_blink_tween.tween_property(_clue_button, "modulate:a", 1.0, BLINK_SECONDS)


func _stop_clue_button_blink() -> void:
	if is_instance_valid(_clue_button_blink_tween):
		_clue_button_blink_tween.kill()
	_clue_button_blink_tween = null
	_clue_button.modulate.a = 1.0
