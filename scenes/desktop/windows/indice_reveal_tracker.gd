extends RefCounted
class_name IndiceRevealTracker
## Surveille une liste de (Control, clue_id) à l'intérieur d'un
## ScrollContainer et débloque chaque indice la première fois que son Control
## entre dans la zone visible du scroll — pour les écrans où le texte portant
## un indice peut être construit hors-écran (dump SMS, corps de mail, fiche
## OSINT), contrairement au chat en direct ou à la galerie où le contenu est
## toujours entièrement visible dès son apparition (unlock immédiat là-bas,
## pas besoin de ce tracker).
##
## Le son de découverte n'est pas géré ici : il suit automatiquement
## ClueManager.unlock() via SfxPlayer, un seul point d'écoute pour toutes les
## sources d'indices (voir sfx_player.gd).
##
## Une instance par "session d'affichage" (une conversation SMS sélectionnée,
## un mail ouvert, une recherche OSINT) — recréer l'instance à chaque
## reconstruction du contenu plutôt que réutiliser la même, pour repartir
## d'une liste de guet vide.

var _scroll: ScrollContainer
var _watched: Array[Dictionary] = []
var _value_changed_callable: Callable
var _resized_callable: Callable


func _init(scroll: ScrollContainer) -> void:
	_scroll = scroll
	_value_changed_callable = func(_v: float) -> void: check_visible()
	_resized_callable = check_visible
	_scroll.get_v_scroll_bar().value_changed.connect(_value_changed_callable)
	_scroll.resized.connect(_resized_callable)


## A appeler pour chaque Control porteur d'un indice, juste après sa
## construction. Sans effet si l'indice est déjà débloqué (rien à annoncer).
func watch(control: Control, clue_id: String) -> void:
	if clue_id.is_empty() or ClueManager.is_unlocked(clue_id):
		return
	_watched.append({"control": control, "clue_id": clue_id})


## A appeler quand cette instance est remplacée par une nouvelle (nouvelle
## conversation/mail/recherche affichée) — sans ça, ses connexions au
## ScrollContainer partagé (jamais recréé, lui, contrairement à son contenu)
## restaient actives indéfiniment et se déclenchaient encore sur un scroll
## suivant, avec des Control déjà libérés par la reconstruction entre-temps
## (plantage constaté : "Trying to assign invalid previously freed instance").
func dispose() -> void:
	var v_bar := _scroll.get_v_scroll_bar()
	if v_bar.value_changed.is_connected(_value_changed_callable):
		v_bar.value_changed.disconnect(_value_changed_callable)
	if _scroll.resized.is_connected(_resized_callable):
		_scroll.resized.disconnect(_resized_callable)
	_watched.clear()


## A appeler une fois juste après avoir tout construit (rattrape ce qui est
## déjà visible sans attendre un scroll), puis automatique ensuite à chaque
## scroll/redimensionnement tant qu'il reste des ids en attente.
func check_visible() -> void:
	if _watched.is_empty():
		return
	var view_rect := Rect2(_scroll.global_position, _scroll.size)
	var still_pending: Array[Dictionary] = []
	for entry in _watched:
		## Non typé exprès : assigner un Object déjà libéré à une variable
		## typée Control plante avant même is_instance_valid() (voir le
		## commentaire de dispose() ci-dessus pour la cause).
		var control = entry["control"]
		if not is_instance_valid(control):
			continue
		if view_rect.intersects(Rect2(control.global_position, control.size)):
			ClueManager.unlock(entry["clue_id"])
		else:
			still_pending.append(entry)
	_watched = still_pending
