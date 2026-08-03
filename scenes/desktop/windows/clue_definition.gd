extends RefCounted
class_name ClueDefinition
## One row of data/clues.csv : un indice précis, rattaché à une mission et à
## une ClueCategory. Le texte affiché vit dans translations/indices.csv, sous
## la clé `id` elle-même.

var id: String
var mission_id: int
var category_id: String
