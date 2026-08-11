extends Control
## Écran "Crédits" accessible depuis le menu principal. Le contenu vient d'un
## fichier .txt brut (data/credits_<locale>.txt), pas de ui.csv : c'est un
## long bloc de texte à mettre à jour au fil du projet (nouvel asset, nouvelle
## source) et le contenu doit rester modifiable directement dans le fichier
## sans repasser par l'éditeur Godot. Repli sur le français si la version
## anglaise n'existe pas encore (voir project_whitehat_target_languages).

const CREDITS_PATH_TEMPLATE := "res://data/credits_%s.txt"
const FALLBACK_LOCALE := "fr"
## Repère un lien http(s) dans le texte brut pour le rendre cliquable — voir
## _linkify(). Pas d'ancre de fin ($) : un lien s'arrête au premier espace/
## saut de ligne, jamais au caractère de ponctuation suivant.
const URL_PATTERN := "https?://[^\\s]+"

@onready var _credits_label: RichTextLabel = %CreditsLabel
@onready var _back_button: Button = %BackButton
@onready var _uptime_label: Label = %UptimeLabel
@onready var _uptime_timer: Timer = %UptimeTimer

var _start_ticks_msec: int = 0
var _url_regex := RegEx.new()


func _ready() -> void:
	_start_ticks_msec = Time.get_ticks_msec()
	_uptime_timer.timeout.connect(_update_uptime_label)
	_update_uptime_label()

	_url_regex.compile(URL_PATTERN)
	_back_button.pressed.connect(_on_back_pressed)
	_credits_label.meta_clicked.connect(_on_credits_meta_clicked)
	# Curseur "main" seulement au survol d'un vrai lien, pas sur tout le bloc
	# de texte — cohérent avec le CURSOR_POINTING_HAND déjà utilisé sur les
	# lignes cliquables de SmsSection/MailSection.
	_credits_label.meta_hover_started.connect(func(_meta) -> void: _credits_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND)
	_credits_label.meta_hover_ended.connect(func(_meta) -> void: _credits_label.mouse_default_cursor_shape = Control.CURSOR_ARROW)
	_credits_label.text = _linkify(_load_credits_text())


func _update_uptime_label() -> void:
	var elapsed_sec: int = int((Time.get_ticks_msec() - _start_ticks_msec) / 1000.0)
	var days: int = elapsed_sec / 86400
	var hours: int = (elapsed_sec % 86400) / 3600
	var minutes: int = (elapsed_sec % 3600) / 60
	_uptime_label.text = "Up %dd %02d:%02d" % [days, hours, minutes]


func _load_credits_text() -> String:
	var path := CREDITS_PATH_TEMPLATE % Settings.locale
	if not FileAccess.file_exists(path):
		path = CREDITS_PATH_TEMPLATE % FALLBACK_LOCALE
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Credits: fichier introuvable (%s)" % path)
		return ""
	return file.get_as_text()


## Échappe les crochets littéraux du fichier .txt (au cas où — le fichier
## reste éditable à la main sans connaître le BBCode) puis entoure chaque URL
## de [url=...]...[/url] coloré en accent, pour la rendre cliquable et
## visuellement reconnaissable comme un lien.
func _linkify(raw_text: String) -> String:
	var escaped := raw_text.replace("[", "[lb]").replace("]", "[rb]")
	var accent := "#%s" % Palette.TEXT_ACCENT.to_html(false)
	return _url_regex.sub(escaped, "[color=%s][url=$0]$0[/url][/color]" % accent, true)


func _on_credits_meta_clicked(meta: Variant) -> void:
	OS.shell_open(String(meta))


## Même comportement que login.gd : retour direct au menu, sans fondu ni
## coupure de la musique (le morceau du menu principal continue de jouer).
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
