extends Control
class_name PlayerThought
## Petit encart "pensée du joueur" — façon aparté intérieur, pas un dialogue
## qui attend une action. Réutilisable : n'importe quel écran instancie cette
## scène, lui donne son texte (déjà traduit par l'appelant, voir `text`) puis
## l'ajoute à l'arbre ; elle se montre, reste affichée quelques secondes puis
## se referme et se libère toute seule, sans rien à nettoyer côté appelant.
##
## Premier appel : desktop.gd, au moment où RelayGhost contacte le joueur.

## Durée d'affichage plein, avant le fondu de sortie.
const HOLD_SECONDS := 5.0
const FADE_SECONDS := 0.4

## Texte affiché — à renseigner avant l'ajout à l'arbre (ex. juste après
## instantiate()), déjà passé par tr() côté appelant : ce composant reste
## indépendant de toute table de traduction précise.
var text: String = ""

@onready var _pseudo_label: Label = %PseudoLabel
@onready var _thought_label: Label = %ThoughtLabel


func _ready() -> void:
	_pseudo_label.text = PlayerSession.pseudo
	_thought_label.text = text

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)
