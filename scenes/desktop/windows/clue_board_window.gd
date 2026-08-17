extends Control
class_name ClueBoardWindow
## Fenêtre "collecte d'indices" : même chrome (fond/cadre vert, barre de
## titre) et même style d'ancrage (centrée, taille fixe en pixels) que les
## autres fenêtres du bureau (ex. ChatWindow/OsintWindow, voir les ancres de
## la scène) — juste plus grande (2400x1200) puisque le tableau d'enquête
## peut compter plusieurs colonnes de catégories. Le contenu (ClueBoard) est
## générique par mission — voir clue_board.gd — donc réutilisable tel quel
## pour les prochaines missions.
##
## Bouton "×" plutôt que "—" (réduction) : contrairement aux autres fenêtres,
## celle-ci se rouvre toujours au même endroit (le bouton "Indice" du header,
## en permanence visible) — pas besoin d'une icône dans la barre des tâches en
## plus pour la retrouver, se fermer directement suffit (voir desktop.gd,
## _on_clue_button_pressed : l'instance est réutilisée en interne, seule sa
## visibilité change). Déplaçable par la barre de titre comme les autres,
## malgré tout (voir _on_title_bar_gui_input) — sa position n'est pas
## persistée, elle repart centrée à chaque nouvelle ouverture de session.

## Bubbled up to desktop.gd, qui décide ce qu'ouvrir "générer le rapport"
## veut dire (voir report_generation_screen) — cette fenêtre ne connaît que
## son propre bouton.
signal generate_report_requested
## Bubbled up à desktop.gd (même schéma que VaultSection — texte déjà
## traduit + sa clé ui.csv, voir vault_section.gd) : déclenché quand le
## joueur clique GÉNÉRER LE RAPPORT alors qu'il est encore grisé (voir
## _on_generate_report_button_gui_input). La clé permet à
## SaveManager.record_thought() de rejournaliser cette pensée dans la bonne
## langue si le joueur change de langue en cours de partie.
signal thought_requested(text: String, translation_key: String)

## Même recette de clignotement que le bouton Indice du header (voir
## desktop_header.gd::_start_clue_button_blink) — attire l'oeil sur GENERER
## LE RAPPORT dès qu'il devient bleu/cliquable, s'arrête au premier clic.
const BLINK_MIN_ALPHA := 0.35
const BLINK_SECONDS := 1.4
const WARNING_DIALOG := preload("res://scenes/ui/warning_dialog.tscn")

@export var mission_id: int = 1:
	set(value):
		mission_id = value
		if is_node_ready():
			_apply_mission()

@onready var _title_bar: PanelContainer = %TitleBar
@onready var _close_button: Button = %CloseButton
@onready var _question_label: Label = %QuestionLabel
@onready var _clue_board: ClueBoard = %ClueBoard
@onready var _generate_report_button: Button = %GenerateReportButton

## WarningDialog (voir scenes/ui/warning_dialog.gd), pas ConfirmationDialog —
## même raison que main_menu.gd::_new_game_confirm_dialog (Window clippe le
## halo diffus). Instanciée en code, pas posée dans la scène.
var _report_confirm_dialog: WarningDialog

var _report_button_blink_tween: Tween
var _dragging: bool = false


func _ready() -> void:
	## Cachée jusqu'à ce que Layout (VBoxContainer) ait fini sa propre passe
	## de mise en page — sinon la toute première frame peut afficher TitleBar
	## avec une taille pas encore stabilisée, contrairement à Background/
	## BorderOverlay (de simples Panel, corrects dès l'entrée dans l'arbre) :
	## coin de la barre de titre décalé par rapport au cadre, visible jusqu'au
	## prochain redraw de cette zone (potentiellement jamais, si rien d'autre
	## n'y change) — voir _reveal_once_settled().
	visible = false
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_generate_report_button.pressed.connect(_on_generate_report_button_pressed)
	## gui_input plutôt que pressed pour ce second câblage : un Button désactivé
	## n'émet jamais "pressed", mais reçoit toujours gui_input (voir
	## _on_generate_report_button_gui_input) — c'est justement le clic pendant
	## que le bouton est grisé qu'on veut intercepter ici.
	_generate_report_button.gui_input.connect(_on_generate_report_button_gui_input)
	## Un Button désactivé n'a nativement aucun retour visuel au survol (voir
	## PrimaryButton/styles/disabled dans main_theme.tres, seule apparence
	## appliquée quel que soit l'état de la souris) — ce couple de signaux
	## éclaircit légèrement le bouton grisé au survol pour signaler qu'il reste
	## cliquable (voir _on_generate_report_button_mouse_entered/exited),
	## seulement tant qu'il est grisé (voir garde interne) : ne touche pas au
	## clignotement bleu une fois débloqué.
	_generate_report_button.mouse_entered.connect(_on_generate_report_button_mouse_entered)
	_generate_report_button.mouse_exited.connect(_on_generate_report_button_mouse_exited)
	## WarningDialog (voir scenes/ui/warning_dialog.gd), pas ConfirmationDialog
	## — même raison que main_menu.gd::_new_game_confirm_dialog (Window clippe
	## le halo diffus). "Non" n'a besoin d'aucun câblage : cancelled() cache
	## déjà la boîte toute seule (voir WarningDialog._on_cancel_pressed), et
	## cette fenêtre n'a jamais été cachée derrière — on s'y retrouve donc
	## automatiquement.
	_report_confirm_dialog = WARNING_DIALOG.instantiate()
	add_child(_report_confirm_dialog)
	_report_confirm_dialog.confirmed.connect(_on_report_confirmed)
	ClueManager.clue_unlocked.connect(_on_clue_unlocked)
	_apply_mission()
	_reveal_once_settled()


## Deux frames d'attente : une pour que Layout termine sa passe de mise en
## page, une seconde par marge de sécurité (le moteur peut s'y prendre à
## plusieurs frames selon la profondeur de l'arbre de conteneurs).
func _reveal_once_settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	visible = true


func _apply_mission() -> void:
	_clue_board.setup(mission_id)
	_question_label.text = tr("CLUEBOARD_TITLE_M%d" % mission_id)
	## Caché tant que l'enquête proprement dite n'a pas commencé (voir
	## ClueManager.has_mission_started) — sinon la question de la mission
	## s'affiche dès la toute première ouverture, avant même d'avoir mis les
	## pieds sur le téléphone d'Alizée.
	_question_label.visible = ClueManager.has_mission_started(mission_id)
	_update_report_button()


## Un indice fraîchement débloqué peut être le tout premier de cette mission
## à suivre la convention "M<mission_id>_..." — révèle alors le titre sans
## attendre une fermeture/réouverture de la fenêtre.
func _on_clue_unlocked(_clue_id: String) -> void:
	if not _question_label.visible:
		_question_label.visible = ClueManager.has_mission_started(mission_id)
	_update_report_button()


## Invisible tant qu'aucun indice de la mission en cours n'existe encore (même
## condition que _question_label, voir _apply_mission) — pas de raison de
## montrer "GÉNÉRER LE RAPPORT" avant même d'avoir commencé à fouiller le
## téléphone d'Alizée. Une fois visible : grisé (PrimaryButton) tant que la
## résolution de CETTE mission n'est pas trouvée, bleu (ImportantButton, voir
## main_theme.tres) et cliquable une fois débloquée — même condition générique
## que desktop_header.gd, mais scopée à mission_id puisque cette fenêtre en a
## une propre.
func _update_report_button() -> void:
	# Remise à blanc systématique : si le joueur survolait encore le bouton
	# grisé pile au moment où l'indice de résolution se débloque, l'éclaircissement
	# du survol (RGB) resterait sinon collé par-dessus le clignotement bleu qui
	# ne touche que l'alpha (voir _start_report_button_blink) — jamais visible
	# autrement, cette ligne ne change rien en dehors de ce cas précis.
	_generate_report_button.modulate = Color.WHITE
	var mission_started := ClueManager.has_mission_started(mission_id)
	_generate_report_button.visible = mission_started
	if not mission_started:
		_stop_report_button_blink()
		return

	var unlocked := ClueManager.has_unlocked_mission_solution(mission_id)
	_generate_report_button.disabled = not unlocked
	_generate_report_button.theme_type_variation = &"ImportantButton" if unlocked else &"PrimaryButton"
	if unlocked:
		_start_report_button_blink()
	else:
		_stop_report_button_blink()


func _on_close_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	hide()


## Glisser par la barre de titre, comme OsintWindow/ThoughtLogWindow.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var max_position: Vector2 = get_parent_area_size() - size
		position = (position + event.relative).clamp(Vector2.ZERO, max_position)


## N'émet pas encore generate_report_requested : demande d'abord confirmation
## (voir _on_report_confirmed), puisque passer à l'étape suivante est
## irréversible pour le joueur (voir REPORT_CONFIRM_WARNING).
func _on_generate_report_button_pressed() -> void:
	SfxPlayer.play(SfxPlayer.UI_CLICK_SFX)
	_stop_report_button_blink()
	# MessageLabel est rouge par défaut (voir warning_dialog.tscn) : seule
	# REPORT_CONFIRM_WARNING ("pas de retour en arrière") doit rester rouge,
	# le reste repasse en blanc via bbcode (voir WarningDialog.set_text).
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


## Un Button désactivé n'émet jamais "pressed" (voir le connect de gui_input
## plus haut) — sans cette interception, cliquer dessus pendant qu'il est
## grisé ne faisait rien du tout, sans indiquer au joueur pourquoi il ne peut
## pas encore générer le rapport.
func _on_generate_report_button_gui_input(event: InputEvent) -> void:
	if not _generate_report_button.disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		thought_requested.emit(tr("CLUEBOARD_REPORT_LOCKED_THOUGHT"), "CLUEBOARD_REPORT_LOCKED_THOUGHT")


## Léger éclaircissement (pas une nouvelle StyleBox, juste modulate — discret,
## et sans risque de conflit avec le style "disabled" du thème). Ne fait rien
## une fois débloqué : le clignotement bleu existant suffit déjà à signaler
## que le bouton est cliquable dans cet état.
func _on_generate_report_button_mouse_entered() -> void:
	if _generate_report_button.disabled:
		_generate_report_button.modulate = Color(1.15, 1.15, 1.15, 1.0)


func _on_generate_report_button_mouse_exited() -> void:
	if _generate_report_button.disabled:
		_generate_report_button.modulate = Color.WHITE


## Même recette que desktop_header.gd::_start_tor_blink/_start_clue_button_blink.
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
