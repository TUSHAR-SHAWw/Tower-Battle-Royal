class_name ElementalComponent
extends Node

## Handles elemental resistances, weaknesses, and status effects for an entity.

signal status_applied(element_id: StringName, duration: float)
signal status_removed(element_id: StringName)
signal status_damaged(element_id: StringName, amount: float)

@export var base_resistances: Dictionary = {}

var _status_effects: Dictionary = {}  # element_id -> {timer, stacks, max_stacks}

func _ready() -> void:
	# Default resistances
	if base_resistances.is_empty():
		base_resistances = {
			&"fire": 1.0,
			&"ice": 1.0,
			&"lightning": 1.0,
			&"poison": 1.0,
			&"physical": 1.0
		}


func _physics_process(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for element_id in _status_effects:
		var effect: Dictionary = _status_effects[element_id]
		effect.timer -= delta
		effect.tick_timer -= delta
		
		if effect.tick_timer <= 0.0:
			_tick_status(element_id)
			effect.tick_timer = _get_tick_interval(element_id)
		
		if effect.timer <= 0.0:
			to_remove.append(element_id)
	
	for id in to_remove:
		_remove_status(id)


func _get_element_data(element_id: StringName) -> ElementalType:
	# Load element data from resource
	var path := "res://resources/elements/%s.tres" % element_id
	return load(path) as ElementalType


func _get_tick_interval(element_id: StringName) -> float:
	var data := _get_element_data(element_id)
	return data.status_tick_interval if data != null else 1.0


func apply_status(element_id: StringName, duration: float = -1.0, stacks: int = 1) -> void:
	var data := _get_element_data(element_id)
	if data == null:
		return
	
	var dur := duration if duration > 0 else data.status_duration
	var max_stacks := 5
	
	if _status_effects.has(element_id):
		var effect: Dictionary = _status_effects[element_id]
		effect.stacks = min(max_stacks, effect.stacks + stacks)
		effect.timer = max(effect.timer, dur)
	else:
		_status_effects[element_id] = {
			"timer": dur,
			"tick_timer": data.status_tick_interval,
			"stacks": stacks
		}
		status_applied.emit(element_id, dur)


func _tick_status(element_id: StringName) -> void:
	if not _status_effects.has(element_id):
		return
	
	var effect: Dictionary = _status_effects[element_id]
	var data := _get_element_data(element_id)
	if data == null:
		return
	
	var damage: float = data.status_dps * effect.stacks * data.status_tick_interval
	status_damaged.emit(element_id, damage)
	SignalHub.elemental_status_damaged.emit(get_parent(), element_id, damage)


func _remove_status(element_id: StringName) -> void:
	_status_effects.erase(element_id)
	status_removed.emit(element_id)


func has_status(element_id: StringName) -> bool:
	return _status_effects.has(element_id)


func get_status_stacks(element_id: StringName) -> int:
	return _status_effects[element_id].stacks if _status_effects.has(element_id) else 0


func get_status_remaining(element_id: StringName) -> float:
	return _status_effects[element_id].timer if _status_effects.has(element_id) else 0.0


func get_resistance(element_id: StringName) -> float:
	return base_resistances.get(element_id, 1.0)


func set_resistance(element_id: StringName, value: float) -> void:
	base_resistances[element_id] = clamp(value, 0.0, 2.0)


func take_elemental_damage(amount: float, element_id: StringName) -> float:
	var mult := get_resistance(element_id)
	return amount * mult


func clear_all_status() -> void:
	for id in _status_effects.keys():
		_remove_status(id)


func debug_line() -> String:
	var parts: Array[String] = []
	for id in _status_effects:
		var e: Dictionary = _status_effects[id]
		parts.append("%s x%d (%.1fs)" % [id, e.stacks, e.timer])
	return "elements: %s" % (", ".join(parts) if parts else "none")