class_name CentralPlatformController
extends Node2D

## Central descending platform that travels top → bottom of the tower.
##
## The platform starts at the highest floor and descends at a configurable
## speed, reaching each floor in sequence. Players can board it to skip ahead
## in the tower, but it only stops for a brief window at each floor.
## The platform is visible on the map as a distinct entity.

signal arrived_at_floor(floor_id: int)
signal descent_started(from_floor: int, to_floor: int)
signal descent_speed_changed(new_speed: float)

## How fast the platform descends (pixels per second).
@export var descent_speed: float = 32.0
## How long the platform pauses at each floor.
@export var pause_duration: float = 8.0
## Floor IDs the platform stops at (in descending order from top).
@export var floor_stops: Array[int] = []
## The platform starts at this floor (typically the top floor).
@export var starting_floor: int = 1
## Radius of the platform (visual).
@export var platform_radius: float = 120.0

var current_floor_index: int = 0
var current_floor: int = 1
var _state: StringName = &"idle"
var _pause_timer: float = 0.0
var _speed: float = descent_speed
var _players_on_platform: Array[Node] = []


func _ready() -> void:
	if floor_stops.is_empty():
		floor_stops = [1]
	if floor_stops.size() > 0:
		current_floor = floor_stops[0]
	else:
		current_floor = 1


func start_descent() -> void:
	if _state != &"idle":
		return
	_state = &"traveling"
	current_floor_index = 0
	if floor_stops.size() > 0:
		current_floor = floor_stops[0]
	var next_floor := current_floor
	if floor_stops.size() > 1:
		next_floor = floor_stops[1]
	descent_started.emit(current_floor, next_floor)


func accelerate(multiplier: float) -> void:
	_speed = descent_speed * multiplier
	descent_speed_changed.emit(_speed)


func stop() -> void:
	_speed = 0.0
	descent_speed_changed.emit(0.0)


func resume() -> void:
	_speed = descent_speed
	descent_speed_changed.emit(_speed)


func _physics_process(delta: float) -> void:
	match _state:
		&"traveling":
			position.y += _speed * delta
		&"paused":
			_pause_timer -= delta
			if _pause_timer <= 0.0:
				_advance_to_next_floor()


func _advance_to_next_floor() -> void:
	if current_floor_index + 1 >= floor_stops.size():
		_state = &"arrived"
		return

	current_floor_index += 1
	current_floor = floor_stops[current_floor_index]
	_state = &"paused"
	_pause_timer = pause_duration
	arrived_at_floor.emit(current_floor)
	SignalHub.central_platform_floor_reached.emit(current_floor)


func register_player(player: Node) -> void:
	if not _players_on_platform.has(player):
		_players_on_platform.append(player)


func unregister_player(player: Node) -> void:
	_players_on_platform.erase(player)


func get_players() -> Array[Node]:
	return _players_on_platform.duplicate(true)


func get_current_floor() -> int:
	return current_floor


func get_state() -> StringName:
	return _state


func debug_line() -> String:
	return "Platform: floor %d (%s, speed=%.1f)" % [current_floor, _state, _speed]
