class_name InputPrediction
extends RefCounted

## Stores client input history for rollback/reconciliation.
##
## When the server sends a correction (snapshot with different state),
## the client replays all unacknowledged inputs from the recorded history
## to resynchronize smoothly.

var _tick_rate: int = 60
var _input_history: Array[Dictionary] = []
var _max_history: int = NetworkTypes.INPUT_HISTORY_SIZE
var _last_server_tick: int = 0
var _pending_inputs: Array[Dictionary] = []


func set_tick_rate(rate: int) -> void:
	_tick_rate = rate


func store_input(input: InputIntent, tick: int, sequence: int) -> void:
	_input_history.append({
		"tick": tick,
		"sequence": sequence,
		"intent": _serialize_intent(input),
	})
	if _input_history.size() > _max_history:
		_input_history.pop_front()


func _serialize_intent(intent: InputIntent) -> Dictionary:
	return {
		"move_dir": intent.move_dir,
		"aim_dir": intent.aim_dir,
		"aim_position": intent.aim_position,
		"has_aim_position": intent.has_aim_position,
		"sprint_held": intent.sprint_held,
		"fire_held": intent.fire_held,
		"fire_pressed": intent.fire_pressed,
		"reload_pressed": intent.reload_pressed,
		"melee_pressed": intent.melee_pressed,
		"interact_pressed": intent.interact_pressed,
		"use_pressed": intent.use_pressed,
		"map_pressed": intent.map_pressed,
		"merge_pressed": intent.merge_pressed,
		"requested_slot": intent.requested_slot,
	}


func get_history_since(tick: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _input_history:
		if entry.tick >= tick:
			result.append(entry.duplicate(true))
	return result


func acknowledge_input(sequence: int) -> void:
	# Remove acknowledged inputs from history
	for i in range(_input_history.size() - 1, -1, -1):
		if _input_history[i].sequence <= sequence:
			_input_history.remove_at(i)


func needs_correction(server_tick: int, server_state: Dictionary) -> bool:
	_last_server_tick = server_tick
	# The caller should compare the server state with the predicted state.
	# This method is a placeholder hook for the prediction logic.
	return false


func replay_inputs(start_tick: int, end_tick: int) -> Array[Dictionary]:
	var replay: Array[Dictionary] = []
	for entry in _input_history:
		if entry.tick >= start_tick and entry.tick <= end_tick:
			replay.append(entry.duplicate(true))
	replay.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.tick < b.tick
	)
	return replay


func clear() -> void:
	_input_history.clear()
	_pending_inputs.clear()
