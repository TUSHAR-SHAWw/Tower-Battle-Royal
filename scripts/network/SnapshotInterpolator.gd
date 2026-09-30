class_name SnapshotInterpolator
extends RefCounted

## Interpolates remote entity state between received snapshots.
##
## Uses a fixed interpolation delay (buffer of snapshots) to smooth
## between server ticks. Entities not updated since the last tick fade
## out or hold their last known state depending on type.

var _tick_rate: int = 60
var _interp_delay_ticks: int = 2  # buffer of ~33ms at 60tick
var _snapshots: Array[NetMessage.NetSnapshot] = []
var _entities: Dictionary[int, Dictionary] = {}
var _last_tick: int = 0

var _pending_spawns: Array[Dictionary] = []
var _pending_despawns: Array[int] = []
var _pending_enemy_spawns: Array[Dictionary] = []
var _pending_enemy_despawns: Array[int] = []


func set_tick_rate(rate: int) -> void:
	_tick_rate = rate
	_interp_delay_ticks = max(1, int(rate / 30.0))


func add_snapshot(snapshot: NetMessage.NetSnapshot) -> void:
	if snapshot.server_tick <= _last_tick:
		return

	_last_tick = snapshot.server_tick
	_snapshots.append(snapshot)

	# Prune old snapshots
	while _snapshots.size() > NetworkTypes.MAX_SNAPSHOTS:
		_snapshots.pop_front()

	# Track added/removed entities
	var current_ids: Array[int] = []
	for state in snapshot.player_states:
		current_ids.append(state.net_id)
		if not _entities.has(state.net_id):
			_pending_spawns.append({
				"net_id": state.net_id,
				"position": state.position,
				"state": state,
				"is_enemy": false,
			})
		_entities[state.net_id] = {
			"current": state,
			"previous": state,
			"last_update_tick": snapshot.server_tick,
			"is_enemy": false,
		}

	for state in snapshot.enemy_states:
		current_ids.append(state.net_id)
		if not _entities.has(state.net_id):
			_pending_enemy_spawns.append({
				"net_id": state.net_id,
				"position": state.position,
				"state": state,
			})
		_entities[state.net_id] = {
			"current": state,
			"previous": state,
			"last_update_tick": snapshot.server_tick,
			"is_enemy": true,
		}

	# Detect despawns
	for net_id: int in _entities.keys():
		if net_id not in current_ids:
			_pending_despawns.append(net_id)
			_entities.erase(net_id)


func update(_delta: float) -> void:
	# Interpolation is performed by entities reading get_interpolated_state
	pass


func get_interpolated_state(net_id: int, tick: int) -> Dictionary:
	if not _entities.has(net_id):
		return {}

	var entity := _entities[net_id]
	var current: NetMessage.NetPlayerState = entity.current
	var previous: NetMessage.NetPlayerState = entity.previous

	if current == previous:
		return _state_to_dict(current)

	var target_tick: int = tick - _interp_delay_ticks
	var total_ticks: int = tick
	var prev_tick: int = total_ticks - 1

	if prev_tick == total_ticks:
		return _state_to_dict(current)

	var ratio := float(target_tick - prev_tick) / float(total_ticks - prev_tick)
	ratio = clamp(ratio, 0.0, 1.0)

	var prev_pos: Vector2 = previous.position if previous else current.position
	var prev_vel: Vector2 = previous.velocity if previous else current.velocity
	var prev_rot: float = previous.rotation if previous else current.rotation

	var interp_pos: Vector2 = prev_pos.lerp(current.position, ratio)
	var interp_vel: Vector2 = prev_vel.lerp(current.velocity, ratio)
	var interp_rot: float = lerp(prev_rot, current.rotation, ratio)

	return {
		"position": interp_pos,
		"velocity": interp_vel,
		"rotation": interp_rot,
		"state": current.state,
		"health": current.health,
		"max_health": current.max_health,
		"aim_direction": current.aim_direction,
	}


func _state_to_dict(state: NetMessage.NetPlayerState) -> Dictionary:
	return {
		"position": state.position,
		"velocity": state.velocity,
		"rotation": state.rotation,
		"state": state.state,
		"health": state.health,
		"max_health": state.max_health,
		"aim_direction": state.aim_direction,
	}


func get_pending_spawns() -> Array[Dictionary]:
	var result := _pending_spawns.duplicate(true)
	_pending_spawns.clear()
	return result


func get_pending_despawns() -> Array[int]:
	var result := _pending_despawns.duplicate(true)
	_pending_despawns.clear()
	return result


func get_pending_enemy_spawns() -> Array[Dictionary]:
	var result := _pending_enemy_spawns.duplicate(true)
	_pending_enemy_spawns.clear()
	return result


func get_pending_enemy_despawns() -> Array[int]:
	var result := _pending_enemy_despawns.duplicate(true)
	_pending_enemy_despawns.clear()
	return result


func clear() -> void:
	_snapshots.clear()
	_entities.clear()
	_pending_spawns.clear()
	_pending_despawns.clear()
	_pending_enemy_spawns.clear()
	_pending_enemy_despawns.clear()
