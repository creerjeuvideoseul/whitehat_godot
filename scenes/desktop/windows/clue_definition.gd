extends RefCounted
class_name ClueDefinition
## One row of data/clues.txt : un indice précis, rattaché à une mission et à
## une ClueCategory. Le texte affiché vit dans translations/indices.csv, sous
## la clé `id` elle-même.

var id: String
var mission_id: int
var category_id: String
## Date temporelle de l'indice (ex. date d'un SMS), pas sa date de découverte
## par le joueur — pas encore affichée nulle part, chargée en prévision du
## futur remplissage du panneau latéral DesktopCluePanel.
var date: String
