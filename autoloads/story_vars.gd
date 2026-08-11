extends Node
## Autoload singleton: generic narrative variable bag. Dialogue files write
## to it via *explicitly qualified* access — `set StoryVars.some_var += 1`,
## never a bare `using StoryVars` + `some_var`. Persisted by SaveManager at
## checkpoints.
##
## Deliberately not tied to the design doc's ethics/popularity 4-axis score
## system — that's a separate, not-yet-built aggregation layer. This is just
## raw storage for whatever a mission's dialogue wants to track (e.g.
## player_emotion, player_respect).
##
## Why qualified access is required, not a style preference: dialogue_manager
## resolves a *bare* variable name by asking every active state in turn "do
## you have this property" until one says yes — and a brand new story
## variable, before its first write, can't honestly be claimed by anyone.
## Qualified access (`StoryVars.x`) skips that search entirely and talks to
## this object directly, so a permissive default (0 for anything unknown)
## is safe here — it's only ever consulted for a property something already
## specifically asked *this* object for.

var _values: Dictionary = {}

## Every real property this Node already has (native + script) — _get/_set
## below still defer to those instead of shadowing them (e.g. a mission
## variable literally named "name" shouldn't rename the node).
var _native_properties: Dictionary = {}


func _ready() -> void:
	for property in get_property_list():
		_native_properties[property.name] = true


func _get(property: StringName) -> Variant:
	if _native_properties.has(property):
		return null
	return _values.get(property, 0)


func _set(property: StringName, value: Variant) -> bool:
	if _native_properties.has(property):
		return false
	_values[property] = value
	return true


func get_all() -> Dictionary:
	return _values.duplicate()


func load_all(values: Dictionary) -> void:
	_values = values.duplicate()
