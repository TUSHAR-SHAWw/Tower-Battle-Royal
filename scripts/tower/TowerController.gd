class_name TowerController
extends Node

## Controls the vertical tower: floor sequencing, travel portals, deletion.
##
## Floors are loaded on-demand. Only the current floor + adjacent floors exist.
## When player reaches travel portal, next floor loads and current begins deletion.

signal floor_changed(new_floor_id: int)
signal floor_deletion_started(floor_id: int)
signal floor_deleted(floor_id: int)
signal travel_started(target_floor: int)
signal travel_completed(target_floor: int)

@export var tower_data: Array[TowerData] = []
@export var tower_resource: TowerResource
@export var initial_floor: int = 1
@export var deletion_delay: float = 5.0  # seconds after leaving before warning starts

var _floor_data_list: Array[TowerData] = []

var _current_floor_id: int = 1
var _current_floor: Node = null
var _next_floor: Node = null
var _state: StringName = &"idle"  # idle, traveling, deleting
var _deletion_timeout_timer: Timer = null

func _ready() -> void:
	if tower_resource != null and not tower_resource.floors.is_empty():
		_floor_data_list = tower_resource.floors
		tower_data = tower_resource.floors
	elif tower_data.is_empty():
		return

	_load_floor(initial_floor)
	SignalHub.tower_floor_changed.emit(_current_floor_id)


func _load_floor(floor_id: int) -> void:
	if floor_id < 1 or floor_id > tower_data.size():
		push_error("TowerController: invalid floor_id %d" % floor_id)
		return

	var data := tower_data[floor_id - 1]
	if data.floor_scene == null:
		push_error("TowerController: floor %d has no scene" % floor_id)
		return

	print("[DEBUG] TowerController: Loading floor %d (bounds: %s, target_floor: %d)" % [
		floor_id,
		data.floor_data.bounds if data.floor_data != null else "null",
		get_portal_target_for(data)
	])

	var floor := data.floor_scene.instantiate()

	# Set the travel target BEFORE floor data, because set_floor_data() spawns the
	# portal and it bails out early while target_floor is still 0.
	_configure_floor_instance(floor, data)

	add_child(floor)
	_place_in_tower(floor, floor_id)
	_current_floor = floor
	_current_floor_id = floor_id

	print("[DEBUG] TowerController: Floor %d loaded, position: %s" % [floor_id, floor.global_position])

	floor_changed.emit(_current_floor_id)
	SignalHub.tower_floor_changed.emit(_current_floor_id)


## Stacks a floor vertically inside the tower.
##
## FloorData.bounds is canonical and identical for every storey (validate()
## enforces it) so the camera framing is uniform. The storey's place in the
## tower therefore comes from its NODE position, not its bounds: floor 1 sits at
## the origin and each floor above is one storey-height further up the shaft.
func _place_in_tower(floor: Node2D, floor_id: int) -> void:
	var storey_height := FloorData.DEFAULT_BOUNDS.size.y
	floor.position = Vector2(0.0, -storey_height * float(floor_id - 1))
	print("[DEBUG] TowerController: Floor %d stacked at y=%.1f" % [floor_id, floor.position.y])


## Returns the floor's world-space rect, which is its canonical bounds shifted by
## where the storey sits in the tower. Camera limits and spawn points must use
## this, not the raw bounds.
func get_floor_world_rect(floor: Node2D, floor_id: int) -> Rect2:
	if floor == null:
		return FloorData.DEFAULT_BOUNDS
	var local_bounds := FloorData.DEFAULT_BOUNDS
	if "floor_data" in floor and floor.floor_data != null:
		local_bounds = floor.floor_data.bounds
	var world_position := floor.to_global(local_bounds.position)
	var world_size := local_bounds.size * floor.global_transform.get_scale()
	return Rect2(world_position, world_size)


## Wires a freshly instantiated floor with its TowerData.
## Order matters: target floor first, then floor data (which spawns the portal).
func _configure_floor_instance(floor: Node, data: TowerData) -> void:
	var target := get_portal_target_for(data)

	if floor.has_method("set_target_floor"):
		floor.set_target_floor(target)
	elif "target_floor" in floor:
		floor.set_target_floor(target)

	if floor.has_method("set_floor_data") and data.floor_data != null:
		floor.set_floor_data(data.floor_data)


func _unload_floor(floor_id: int) -> void:
	if _current_floor != null and _current_floor_id == floor_id:
		_current_floor.queue_free()
		_current_floor = null


func start_travel(target_floor: int) -> void:
	if _state != &"idle":
		return
	if target_floor < 1 or target_floor > tower_data.size():
		return
	
	_state = &"traveling"
	travel_started.emit(target_floor)
	
	# Load next floor
	var data := tower_data[target_floor - 1]
	var floor := data.floor_scene.instantiate()
	_configure_floor_instance(floor, data)

	_place_in_tower(floor, target_floor)
	add_child(floor)
	_next_floor = floor
	
	# Schedule current floor deletion
	call_deferred("_schedule_deletion", _current_floor_id)


func _schedule_deletion(current_floor_id: int) -> void:
	print("[DEBUG] TowerController: Scheduling deletion for floor %d (delay: %.1f seconds)" % [current_floor_id, deletion_delay])
	# Wait for deletion delay, then start warning
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = deletion_delay
	timer.timeout.connect(_start_deletion.bind(current_floor_id))
	add_child(timer)
	timer.start()


func _start_deletion(floor_id: int) -> void:
	if _current_floor == null or _current_floor_id != floor_id:
		return
	
	if _current_floor.has_signal(&"state_changed"):
		var completed := _on_floor_state_changed.bind(floor_id)
		if not _current_floor.is_connected(&"state_changed", completed):
			_current_floor.connect(&"state_changed", completed)

	if _current_floor.has_method("start_deletion"):
		_current_floor.start_deletion()
	
	_state = &"deleting"
	floor_deletion_started.emit(floor_id)
	SignalHub.floor_deletion_started.emit(floor_id)
	
	# Keep a safety timeout for floors that do not implement the deletion-state
	# signal. Normal FloorController instances complete travel as soon as they
	# actually reach DELETED.
	_deletion_timeout_timer = Timer.new()
	_deletion_timeout_timer.one_shot = true
	_deletion_timeout_timer.wait_time = 20.0
	_deletion_timeout_timer.timeout.connect(_finish_deletion.bind(floor_id))
	add_child(_deletion_timeout_timer)
	_deletion_timeout_timer.start()


func _on_floor_state_changed(new_state: int, floor_id: int) -> void:
	if new_state == FloorData.FloorState.DELETED:
		call_deferred("_finish_deletion", floor_id)


func _finish_deletion(floor_id: int) -> void:
	if _current_floor == null or _current_floor_id != floor_id:
		return

	if _deletion_timeout_timer != null:
		_deletion_timeout_timer.stop()
		_deletion_timeout_timer.queue_free()
		_deletion_timeout_timer = null

	print("[DEBUG] TowerController: Finishing deletion for floor %d, resolving next floor (%d -> ?)" % [floor_id, _current_floor_id])
	_unload_floor(floor_id)
	floor_deleted.emit(floor_id)
	SignalHub.floor_deleted.emit(floor_id)

	# Find the next floor to move to (the target floor from start_travel)
	var next_floor_id := _resolve_next_floor(floor_id)
	print("[DEBUG] TowerController: Next floor resolved to: %d" % next_floor_id)
	if _next_floor != null:
		_current_floor = _next_floor
		_current_floor_id = next_floor_id
		_next_floor = null
		print("[DEBUG] TowerController: Switched to preloaded next floor (id: %d)" % next_floor_id)
	else:
		# Fallback: find the next loaded floor in the list
		for data in tower_data:
			if data.floor_id > floor_id:
				_current_floor = null
				_current_floor_id = data.floor_id
				_load_floor(data.floor_id)
				break
	_state = &"idle"

	floor_changed.emit(_current_floor_id)
	travel_completed.emit(_current_floor_id)
	SignalHub.tower_floor_changed.emit(_current_floor_id)


func get_current_floor_id() -> int:
	return _current_floor_id


func get_current_floor() -> Node:
	return _current_floor


## Returns the floor ID that `data`'s travel portal should target.
##
## `TowerData.travel_portal_position.x` encodes the destination floor ID (the .y
## component is unused). Returns 0 when the floor is a dead end — the bottom of
## the tower — so no portal is spawned.
func get_portal_target_for(data: TowerData) -> int:
	if data == null:
		return 0
	var target := int(data.travel_portal_position.x)
	if target <= 0:
		return 0
	# Guard against stale data pointing outside the tower.
	if target < 1 or target > tower_data.size():
		push_warning("TowerController: floor %d targets out-of-range floor %d" % [data.floor_id, target])
		return 0
	return target


## Returns the floor ID that the TravelPortal targets when on `current_floor_id`.
func _resolve_next_floor(current_floor_id: int) -> int:
	for data: TowerData in tower_data:
		if data != null and data.floor_id == current_floor_id:
			var target := get_portal_target_for(data)
			if target > 0:
				return target
			return data.floor_id + 1
	return current_floor_id + 1


func debug_line() -> String:
	return "Tower: floor %d (%s)" % [_current_floor_id, _state]
