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
@export var initial_floor: int = 1
@export var deletion_delay: float = 5.0  # seconds after leaving before warning starts

var _current_floor_id: int = 1
var _current_floor: Node = null
var _next_floor: Node = null
var _state: StringName = &"idle"  # idle, traveling, deleting

func _ready() -> void:
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
	
	var floor := data.floor_scene.instantiate()
	if floor.has_method("set_floor_data") and data.floor_data != null:
		floor.set_floor_data(data.floor_data)
	
	add_child(floor)
	_current_floor = floor
	_current_floor_id = floor_id
	
	floor_changed.emit(_current_floor_id)
	SignalHub.tower_floor_changed.emit(_current_floor_id)


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
	if floor.has_method("set_floor_data") and data.floor_data != null:
		floor.set_floor_data(data.floor_data)
	
	add_child(floor)
	_next_floor = floor
	
	# Schedule current floor deletion
	call_deferred("_schedule_deletion", _current_floor_id)


func _schedule_deletion(current_floor_id: int) -> void:
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
	
	if _current_floor.has_method("start_deletion"):
		_current_floor.start_deletion()
	
	floor_deletion_started.emit(floor_id)
	SignalHub.floor_deletion_started.emit(floor_id)
	
	# Wait for floor to fully delete
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 20.0  # max time for warning + collapse
	timer.timeout.connect(_finish_deletion.bind(floor_id))
	add_child(timer)
	timer.start()


func _finish_deletion(floor_id: int) -> void:
	_unload_floor(floor_id)
	floor_deleted.emit(floor_id)
	SignalHub.floor_deleted.emit(floor_id)
	
	# Complete travel
	_current_floor = _next_floor
	_current_floor_id = floor_id + 1  # assuming sequential
	_next_floor = null
	_state = &"idle"
	
	floor_changed.emit(_current_floor_id)
	travel_completed.emit(_current_floor_id)
	SignalHub.tower_floor_changed.emit(_current_floor_id)


func get_current_floor_id() -> int:
	return _current_floor_id


func get_current_floor() -> Node:
	return _current_floor


func debug_line() -> String:
	return "Tower: floor %d (%s)" % [_current_floor_id, _state]
