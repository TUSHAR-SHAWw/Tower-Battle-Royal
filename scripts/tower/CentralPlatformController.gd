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
signal direction_changed(ascending: bool)
signal player_boarded(player: Node2D)
signal player_left(player: Node2D)

## Travel speed in world units per second.
@export var descent_speed: float = 120.0
## How long the platform pauses at each floor.
@export var pause_duration: float = 8.0
## Floor IDs are stored in ascending order; the platform reverses at each end.
@export var floor_stops: Array[int] = []
## The platform starts at the top of the tower.
@export var starting_floor: int = 50
## Radius of the platform (visual).
@export var platform_radius: float = 120.0

var current_floor_index: int = 0
var current_floor: int = 1
var _state: StringName = &"idle"
var _pause_timer: float = 0.0
var _speed: float = descent_speed
var _index_direction: int = -1
var _players_on_platform: Array[Node] = []
var _area: Area2D


func _ready() -> void:
	_area = get_node_or_null("Area") as Area2D
	if _area != null:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
	if floor_stops.is_empty():
		configure_route(50)
	_reset_to_start()


func configure_route(floor_count: int, start_floor: int = 1) -> void:
	if floor_count < 1:
		push_error("CentralPlatformController: floor_count must be positive.")
		return
	floor_stops.clear()
	for floor_id in range(1, floor_count + 1):
		floor_stops.append(floor_id)
	starting_floor = clampi(start_floor, 1, floor_count)
	current_floor_index = floor_stops.find(starting_floor)
	current_floor = starting_floor
	_index_direction = -1
	_reset_to_start()


func _reset_to_start() -> void:
	if floor_stops.is_empty():
		return
	current_floor_index = floor_stops.find(starting_floor)
	if current_floor_index < 0:
		current_floor_index = floor_stops.size() - 1
	starting_floor = floor_stops[current_floor_index]
	current_floor = starting_floor
	_index_direction = -1
	position = Vector2(0.0, _floor_surface_world_y(current_floor))


func start_descent() -> void:
	if _state != &"idle":
		return
	if floor_stops.size() < 2:
		push_warning("CentralPlatformController: at least two floor stops are required to shuttle.")
		return
	_state = &"traveling"
	_begin_next_leg()


func accelerate(multiplier: float) -> void:
	_speed = descent_speed * maxf(multiplier, 0.0)
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
			_move_toward_next_stop(delta)
		&"paused":
			_pause_timer -= delta
			if _pause_timer <= 0.0:
				_begin_next_leg()


func _move_toward_next_stop(delta: float) -> void:
	if _speed <= 0.0:
		return
	var next_index := current_floor_index + _index_direction
	if next_index < 0 or next_index >= floor_stops.size():
		_reverse_route()
		next_index = current_floor_index + _index_direction
	var destination_y := _floor_surface_world_y(floor_stops[next_index])
	var step := _speed * delta
	var previous_y := position.y
	position.y = move_toward(position.y, destination_y, step)
	var carried_delta := position.y - previous_y
	if not is_zero_approx(carried_delta):
		for player: Node in _players_on_platform.duplicate():
			if is_instance_valid(player) and player is Node2D:
				(player as Node2D).global_position.y += carried_delta
	if is_equal_approx(position.y, destination_y):
		_arrive_at(next_index)


func _arrive_at(index: int) -> void:
	current_floor_index = index
	current_floor = floor_stops[index]
	_state = &"paused"
	_pause_timer = pause_duration
	arrived_at_floor.emit(current_floor)
	SignalHub.central_platform_floor_reached.emit(current_floor)


func _begin_next_leg() -> void:
	if _at_route_end():
		_reverse_route()
	var target_index := current_floor_index + _index_direction
	if target_index < 0 or target_index >= floor_stops.size():
		_state = &"arrived"
		return
	_state = &"traveling"
	descent_started.emit(current_floor, floor_stops[target_index])


func _at_route_end() -> bool:
	var target_index := current_floor_index + _index_direction
	return target_index < 0 or target_index >= floor_stops.size()


func _reverse_route() -> void:
	_index_direction *= -1
	direction_changed.emit(_index_direction > 0)


func _floor_surface_world_y(floor_id: int) -> float:
	return -FloorData.DEFAULT_BOUNDS.size.y * float(floor_id - 1) \
		+ FloorData.DEFAULT_BOUNDS.position.y + FloorData.DEFAULT_BOUNDS.size.y \
		- FloorTileLayout.SLAB_ROWS * FloorTileLayout.TILE - 24.0


func get_display_floor() -> int:
	var storey_height := FloorData.DEFAULT_BOUNDS.size.y
	var estimate := 1 - position.y / storey_height
	return clampi(roundi(estimate), 1, floor_stops.size())


func get_direction_name() -> String:
	return "down" if _index_direction < 0 else "up"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		register_player(body)


func _on_body_exited(body: Node2D) -> void:
	unregister_player(body)


func register_player(player: Node) -> void:
	if player is Node2D and not _players_on_platform.has(player):
		_players_on_platform.append(player)
		player_boarded.emit(player as Node2D)


func unregister_player(player: Node) -> void:
	if _players_on_platform.has(player):
		_players_on_platform.erase(player)
		if player is Node2D:
			player_left.emit(player as Node2D)


func get_players() -> Array[Node]:
	return _players_on_platform.duplicate(true)


func get_current_floor() -> int:
	return current_floor


func get_state() -> StringName:
	return _state


func debug_line() -> String:
	return "Platform: floor %d (%s %s, speed=%.1f)" % [get_display_floor(), get_direction_name(), _state, _speed]
