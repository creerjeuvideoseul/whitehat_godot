extends Control
## The desktop's bottom bar. Left side is a taskbar for minimized windows
## (chat/phone/mail/file explorer, ...) — see add_minimized_window(). Right
## side is connection/session status: an "Aide" button (see
## set_help_button_visible) and an "Historique des pensées" button (see
## ThoughtLogWindow), VPN, TOR relay count, a decorative signal readout, and
## the in-fiction clock (GameClock).

signal thought_log_button_pressed
signal help_button_pressed

@onready var _clock_label: Label = %ClockLabel
@onready var _minimized_windows_bar: HBoxContainer = %MinimizedWindowsBar
@onready var _debug_clue_button: Button = %DebugClueButton
@onready var _help_button: Button = %HelpButton
@onready var _thought_log_button: Button = %ThoughtLogButton

## Toggle state for the debug button — it doesn't ask ClueManager "is
## everything unlocked", it just remembers which action it last took.
var _debug_indices_unlocked: bool = false

## Caché pour l'instant : inutile tant qu'une seule mission existe (tout
## débloquer d'un coup n'a plus grand intérêt une fois la mission 1 avancée).
## Le code de bascule (_on_debug_clue_button_pressed, ClueManager.unlock_all/
## lock_all) reste en place tel quel, prêt à resservir pour tester la
## mission 2+ — repasser à true le moment venu, ne pas supprimer le code.
const DEBUG_CLUE_BUTTON_ENABLED := false


func _ready() -> void:
	_update_clock_label()
	GameClock.tick.connect(_update_clock_label)
	_thought_log_button.pressed.connect(func() -> void: thought_log_button_pressed.emit())
	_help_button.pressed.connect(func() -> void: help_button_pressed.emit())

	# IMPORTANT, à ne pas oublier avant la sortie finale du jeu : retirer ICI
	# ET PARTOUT ailleurs tous les boutons/outils "debug" (voir
	# Settings.IS_PRODUCTION, qui doit alors rester à true en permanence — ce
	# garde-fou seul suffit déjà à ne rien exposer en prod, mais un passage de
	# nettoyage explicite reste plus sûr qu'un flag qu'on pourrait oublier de
	# vérifier).
	if Settings.IS_PRODUCTION:
		_debug_clue_button.queue_free()
	elif DEBUG_CLUE_BUTTON_ENABLED:
		_debug_clue_button.pressed.connect(_on_debug_clue_button_pressed)
	else:
		_debug_clue_button.hide()


func _update_clock_label() -> void:
	_clock_label.text = GameClock.get_display_string()


## Add a taskbar icon for a minimized window. Clicking it calls on_restore
## and removes the icon — the footer doesn't know or care what kind of
## window it is, just its title and how to bring it back.
func add_minimized_window(window_title: String, on_restore: Callable) -> void:
	var button := Button.new()
	button.text = window_title
	button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(func() -> void:
		on_restore.call()
		button.queue_free()
	)
	_minimized_windows_bar.add_child(button)


## For a window reopened some other way than clicking its own taskbar icon
## (e.g. its header shortcut) — drops the now-stale icon so it doesn't sit
## there claiming to "restore" a window that's already showing.
func remove_minimized_window(window_title: String) -> void:
	for child in _minimized_windows_bar.get_children():
		if child is Button and child.text == window_title:
			child.queue_free()


## Caché par défaut dans la scène (voir desktop_footer.tscn) : n'apparaît
## qu'une fois le téléphone d'Alizée révélé (voir desktop.gd::_reveal_alizee_phone,
## après Jean et le terminal système), l'aide n'ayant de sens qu'une fois
## l'enquête vraiment commencée.
func set_help_button_visible(should_show: bool) -> void:
	_help_button.visible = should_show


## Debug only (see Settings.IS_PRODUCTION) : bascule tous les indices de
## toutes les missions entre débloqué et verrouillé. Casse volontairement la
## cohérence de la sauvegarde — c'est un outil de test.
func _on_debug_clue_button_pressed() -> void:
	_debug_indices_unlocked = not _debug_indices_unlocked
	if _debug_indices_unlocked:
		ClueManager.unlock_all()
	else:
		ClueManager.lock_all()

