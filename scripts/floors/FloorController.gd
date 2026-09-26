extends Node2D
class_name FloorController

## Controls a single floor instance.
##
## The floor scene contains:
##   - Visual (background, walls, props)
##   - Collision (walls, boundaries)
##   - Spawn points (players, loot)
##   - State machine (ACTIVE → WARNING → COLLAPSING → DELETED)
##
## Only one floor is loaded at a time. The TowerController swaps floors
## by instancing the FloorController scene with a different FloorData.

signal state_changed(new_state: int)
signal player_entered(player: Node)
signal player_exited(player: Node)

@export var floor_data: FloorData

var _state: int = FloorData.FloorState.ACTIVE
var _state_machine: StateMachine = null
var _warning_timer: float = 0.0
var _collapse_timer: float = 0.0
var _warning_duration: float = 10.0   # seconds of warning before collapse
var _collapse_duration: float = 5.0   # seconds of collapse animation

# Visual nodes
@onready var _visual: Node2D = $Visual
@onready var _collision: Node2D = $Collision
@onready var _spawn_points: Node2D = $SpawnPoints


func _ready() -> void:
	_setup_state_machine()
	
	# Set initial state
	if floor_data != null:
		_state = floor_data.initial_state
		_configure_from_data()
	else:
		_state = FloorData.FloorState.ACTIVE
	
	_update_visual_state()


func _configure_from_data() -> void:
	if floor_data == null:
		push_warning("FloorController: no FloorData assigned yet; call set_floor_data() later.")
		return

	# Apply bounds to camera, collision, etc.
	# The floor visual is drawn to match bounds.
	# Child nodes (walls, spawn points) should be positioned relative to bounds.
	
	# Pass floor data to visual component
	if _visual != null and _visual.get_script() != null and _visual.get_script().resource_path.ends_with("FloorVisual.gd"):
		_visual.floor_data = floor_data
	
	# Update spawn points positions if defined in data
	if floor_data.loot_spawn_points.size() > 0 and _spawn_points != null:
		_clear_spawn_points()
		for i in range(floor_data.loot_spawn_points.size()):
			var pos := floor_data.loot_spawn_points[i]
			var marker := Node2D.new()
			marker.name = "LootSpawn%d" % i
			marker.global_position = pos
			_spawn_points.add_child(marker)
			marker.owner = _spawn_points


## Call this after instancing if floor_data wasn't set in the inspector.
func set_floor_data(data: FloorData) -> void:
	floor_data = data
	_configure_from_data()
	_update_visual_state()


func _setup_state_machine() -> void:
	_state_machine = StateMachine.new()
	_state_machine.name = "FloorStateMachine"
	add_child(_state_machine)
	
	# Create state nodes
	var active_state := _make_state("ACTIVE", FloorData.FloorState.ACTIVE)
	var warning_state := _make_state("WARNING", FloorData.FloorState.WARNING)
	var collapsing_state := _make_state("COLLAPSING", FloorData.FloorState.COLLAPSING)
	var deleted_state := _make_state("DELETED", FloorData.FloorState.DELETED)
	
	_state_machine.add_child(active_state)
	_state_machine.add_child(warning_state)
	_state_machine.add_child(collapsing_state)
	_state_machine.add_child(deleted_state)
	
	_state_machine.initial_state_name = _state_name_from_enum(_state)
	_state_machine.setup(self)
	_state_machine.state_changed.connect(_on_state_changed)
	_state_machine.start()


func _make_state(name: String, state_enum: int) -> State:
	var state := State.new()
	state.name = name
	state.state_name = StringName(name)
	# The state logic is handled in FloorController's physics_process
	# based on _state variable. This is a simple FSM.
	return state


func _state_name_from_enum(state: int) -> StringName:
	match state:
		FloorData.FloorState.ACTIVE: return &"ACTIVE"
		FloorData.FloorState.WARNING: return &"WARNING"
		FloorData.FloorState.COLLAPSING: return &"COLLAPSING"
		FloorData.FloorState.DELETED: return &"DELETED"
	return &"ACTIVE"


func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	_state = _enum_from_state_name(to_state)
	_update_visual_state()
	state_changed.emit(_state)
	
	if to_state == &"WARNING":
		SignalHub.floor_warning_started.emit(floor_data.floor_id, _warning_duration)
	elif to_state == &"DELETED":
		SignalHub.floor_deleted.emit(floor_data.floor_id)


func _enum_from_state_name(name: StringName) -> int:
	match name:
		&"ACTIVE": return FloorData.FloorState.ACTIVE
		&"WARNING": return FloorData.FloorState.WARNING
		&"COLLAPSING": return FloorData.FloorState.COLLAPSING
		&"DELETED": return FloorData.FloorState.DELETED
	return FloorData.FloorState.ACTIVE


func _update_visual_state() -> void:
	# Visual feedback for floor state
	match _state:
		FloorData.FloorState.ACTIVE:
			# Normal appearance
			if _visual != null:
				_visual.modulate = Color.WHITE
		FloorData.FloorState.WARNING:
			# Flashing/red tint
			if _visual != null:
				_visual.modulate = Color(1.0, 0.5, 0.5, 1.0)
		FloorData.FloorState.COLLAPSING:
			# Shaking/darkening
			if _visual != null:
				_visual.modulate = Color(0.8, 0.2, 0.2, 1.0)
		FloorData.FloorState.DELETED:
			# Hidden/disabled
			if _visual != null:
				_visual.visible = false
			if _collision != null:
				_collision.set_collision_layer_value(1, false)
				_collision.set_collision_mask_value(1, false)


func _physics_process(delta: float) -> void:
	match _state:
		FloorData.FloorState.WARNING:
			_warning_timer += delta
			if _warning_timer >= _warning_duration:
				_state_machine.transition_to(&"COLLAPSING")
				_warning_timer = 0.0
				
		FloorData.FloorState.COLLAPSING:
			_collapse_timer += delta
			# Shake effect
			if _visual != null:
				_visual.position = Vector2(
					randf_range(-5.0, 5.0),
					randf_range(-5.0, 5.0)
				)
			if _collapse_timer >= _collapse_duration:
				_state_machine.transition_to(&"DELETED")
				_collapse_timer = 0.0
				
		FloorData.FloorState.DELETED:
			# Floor is gone - could queue_free the whole floor
			pass


## Starts the floor deletion sequence (warning → collapse → deleted).
func start_deletion() -> void:
	if _state == FloorData.FloorState.ACTIVE:
		_state_machine.transition_to(&"WARNING")


## Returns a random spawn point for loot/players.
func get_random_spawn_point() -> Vector2:
	if _spawn_points == null or _spawn_points.get_child_count() == 0:
		# Default to center of bounds
		return floor_data.bounds.position + floor_data.bounds.size * 0.5
	
	var children := _spawn_points.get_children()
	var idx := randi() % children.size()
	return (children[idx] as Node2D).global_position


## Checks if a world position is inside this floor's bounds.
func is_position_inside(position: Vector2) -> bool:
	return floor_data.bounds.has_point(position)


func get_state() -> int:
	return _state


func debug_line() -> String:
	return "Floor %d (%s) [%s]" % [
		floor_data.floor_id if floor_data else -1,
		floor_data.display_name if floor_data else "unknown",
		["ACTIVE", "WARNING", "COLLAPSING", "DELETED"][_state]
	]


func _clear_spawn_points() -> void:
	if _spawn_points != null:
		for child in _spawn_points.get_children():
			child.queue_free()
