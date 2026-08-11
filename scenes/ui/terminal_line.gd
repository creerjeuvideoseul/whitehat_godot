extends RefCounted
class_name TerminalLine
## Une ligne de contenu pour TerminalConsole : soit une ligne de texte simple
## qui se tape lettre par lettre (LINE), soit une ligne de progression qui
## anime un pourcentage jusqu'à sa valeur finale, façon `scp`/`rsync` (PROGRESS).
##
## Le texte est du BBCode déjà entièrement formé (couleurs incluses) —
## TerminalConsole ne fait aucune coloration lui-même, il affiche tel quel ce
## qu'on lui donne. Ça garde la boîte générique : n'importe quel appelant peut
## lui fournir un script différent (voir desktop.gd pour l'exemple de Jean).

enum Kind { LINE, PROGRESS }

var kind: Kind = Kind.LINE

## BBCode complet à taper, lettre par lettre (Kind.LINE uniquement).
var text: String = ""
## Si vrai, TerminalConsole joue le bruitage de frappe (TerminalConsole.typing_sound,
## s'il y en a un) avec un fondu pendant que cette ligne précise se tape —
## pour ne sonner que sur les lignes réellement "tapées" par un humain
## (prompts user@/jean@), pas sur les sorties système ([SYS], [SUCCESS], ...).
var plays_typing_sound: bool = false

# --- Uniquement pour Kind.PROGRESS ---------------------------------------
## Texte de la colonne de gauche (ex: nom de fichier), sans couleur.
var progress_column_text: String = ""
var progress_total_mb: int = 0
var progress_speed_text: String = ""
## Temps final affiché une fois la barre à 100%, format "mm:ss".
var progress_total_time: String = "00:00"
## Durée réelle (secondes) de l'animation du pourcentage à l'écran.
var progress_seconds: float = 1.5


static func text_line(bbcode_text: String, plays_sound: bool = false) -> TerminalLine:
	var line := TerminalLine.new()
	line.text = bbcode_text
	line.plays_typing_sound = plays_sound
	return line


static func progress_line(column_text: String, total_mb: int, speed_text: String, total_time: String, seconds: float = 1.5) -> TerminalLine:
	var line := TerminalLine.new()
	line.kind = Kind.PROGRESS
	line.progress_column_text = column_text
	line.progress_total_mb = total_mb
	line.progress_speed_text = speed_text
	line.progress_total_time = total_time
	line.progress_seconds = seconds
	return line
