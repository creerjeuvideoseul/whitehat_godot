extends Control
class_name DesktopHeader
## The desktop's top bar: OSINT search entry point (left, plus a "Générer le
## rapport" shortcut once available — see set_generate_report_button_visible —
## and a DEBUG-only shortcut next to it, see _debug_skip_to_report_button)
## and system status readouts (right) — TOR indicator, CPU/MEM gauges, current
## pseudo. Always on screen in desktop.tscn; future windows (chat/phone/
## mail/...) render below it, never over it.

const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4

## Fourchette simulée pendant qu'une fenêtre système tourne (terminal, écran
## "chargement des données") — voir set_system_load_spike().
const CPU_SPIKE_MIN_PERCENT := 80.0
const CPU_SPIKE_MAX_PERCENT := 100.0

## En dessous de cette longueur, la recherche par sous-chaîne de
## OsintDatabase.search() matche trop large ("a" ou "al" ressort déjà
## n'importe quel personnage dont le nom/prénom/alias contient ces lettres,
## voir osint_database.gd) — mieux vaut ne rien chercher du tout plutôt que de
## renvoyer un résultat non pertinent (voir _on_search_requested).
const MIN_SEARCH_QUERY_LENGTH := 3

## Bubbled up with the raw (untrimmed) query text — desktop.gd owns what
## "searching" actually opens/updates, this header only knows about the field.
signal osint_search_requested(query: String)
## Bubbled up to desktop.gd, qui décide ce qu'ouvrir veut dire (même contrat
## que osint_search_requested ci-dessus) — ce header ne connaît que son propre
## bouton, pas la logique de déblocage (voir DesktopCluePanel.
## report_availability_changed, qui pilote set_generate_report_button_visible).
signal generate_report_button_pressed

@onready var _tor_icon: TextureRect = %TorIcon
@onready var _pseudo_label: Label = %PseudoLabel
@onready var _search_field: LineEdit = %SearchField
@onready var _search_button: Button = %SearchButton
@onready var _generate_report_button: Button = %GenerateReportButton
@onready var _cpu_gauge: UsageGauge = %CpuGauge
## DEBUG uniquement, à retirer avant la sortie finale — voir _ready()/
## _on_debug_skip_to_report_pressed() plus bas, seuls autres endroits qui en
## parlent (avec le nœud DebugSkipToReportButton dans la scène et la ligne
## qui le cache dans set_investigation_controls_visible ci-dessous) :
## supprimer ces quatre endroits suffit à retirer entièrement ce bouton.
@onready var _debug_skip_to_report_button: Button = %DebugSkipToReportButton


func _ready() -> void:
	_pseudo_label.text = "%s@whos:~" % PlayerSession.pseudo
	_search_button.pressed.connect(_on_search_requested)
	_search_field.text_submitted.connect(func(_text: String) -> void: _on_search_requested())
	_generate_report_button.pressed.connect(func() -> void: generate_report_button_pressed.emit())
	_start_tor_blink()

	# DEBUG — voir la doc de _debug_skip_to_report_button ci-dessus.
	if Settings.IS_PRODUCTION:
		_debug_skip_to_report_button.queue_free()
	else:
		_debug_skip_to_report_button.pressed.connect(_on_debug_skip_to_report_pressed)


## Raccourci de "Générer le rapport" (voir DesktopCluePanel, qui reste seul
## propriétaire de la logique de déblocage/confirmation) — visible dès que la
## résolution de la mission est débloquée, sans attendre que le joueur ouvre
## le panneau Collecte d'indices en FULL pour le trouver.
func set_generate_report_button_visible(should_show: bool) -> void:
	_generate_report_button.visible = should_show


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


## Masque temporairement la recherche darkweb (champ + bouton) et le raccourci
## "Générer le rapport" — pour l'écran de génération du rapport
## (report_generation_screen.gd), qui réutilise ce même header mais où ces
## actions n'ont plus de sens une fois la mission conclue. `should_show`
## plutôt qu'un simple hide() : ce header est partagé avec le bureau normal,
## où ces contrôles doivent rester visibles (le bouton rapport selon sa propre
## disponibilité, voir set_generate_report_button_visible).
func set_investigation_controls_visible(should_show: bool) -> void:
	_search_field.visible = should_show
	_search_button.visible = should_show
	if not should_show:
		_generate_report_button.visible = false
		# DEBUG — voir la doc de _debug_skip_to_report_button plus haut.
		if is_instance_valid(_debug_skip_to_report_button):
			_debug_skip_to_report_button.visible = false


## Rectangle global de la barre de recherche OSINT — pour desktop.gd, qui doit
## positionner la bulle d'aide "Collecte d'indices" juste en dessous (voir
## ClueBoardTooltip.point_at). Control expose déjà get_global_rect() nativement ;
## ce n'est qu'un raccourci pour ne pas exposer _search_field lui-même à un
## autre script.
func get_search_field_global_rect() -> Rect2:
	return _search_field.get_global_rect()


## OsintDatabase.search() matche mot par mot (chaque terme séparé par un
## espace doit apparaître dans la fiche, voir osint_database.gd) : vérifier
## seulement la longueur totale ne suffit pas, une requête comme "a b" (3
## caractères) passerait le garde-fou tout en gardant un terme d'une seule
## lettre qui matche trop large. Chaque terme doit donc individuellement
## atteindre MIN_SEARCH_QUERY_LENGTH.
func _on_search_requested() -> void:
	var query := _search_field.text.strip_edges()
	if query.is_empty():
		return
	for token in query.split(" ", false):
		if token.length() < MIN_SEARCH_QUERY_LENGTH:
			return
	osint_search_requested.emit(query)


## DEBUG uniquement (voir Settings.IS_PRODUCTION et la doc de
## _debug_skip_to_report_button) — raccourci de test pour atteindre
## directement l'état "fin d'enquête, prêt à générer le rapport" (mission 1)
## sans dérouler toute l'enquête à la main. Débloque TOUS les indices plutôt
## que juste ceux de la mission 1 : une seule mission existe pour l'instant,
## et c'est déjà ce que fait le bouton "DEBUG INDICES" du footer (voir
## desktop_footer.gd), actuellement désactivé — ce bouton-ci reste le seul
## outil de ce genre en service tant qu'une seule mission existe.
func _on_debug_skip_to_report_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	ClueManager.unlock_all()


func _start_tor_blink() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_tor_icon, "modulate:a", BLINK_MIN_ALPHA, BLINK_SECONDS)
	tween.tween_property(_tor_icon, "modulate:a", 1.0, BLINK_SECONDS)
