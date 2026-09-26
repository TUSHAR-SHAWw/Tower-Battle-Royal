extends Node2D

## M11 test match: TowerController with 2 floors, central hub, player, and travel portal.

@onready var player: Node = $PlayerInstance
@onready var tower: Node = $TowerController
@onready var hub: Node = $CentralHub

@export var spawn_floor: int = 1


func _ready() -> void:
	# TowerController handles floor loading automatically
	if tower == null or not tower.is_inside_tree():
		push_error("Match: TowerController not found or not ready")
		return
	
	if hub == null or not hub.is_inside_tree():
		push_error("Match: CentralHub not found or not ready")
		return
	
	# Wait for first floor to load, then setup player
	call_deferred("_setup_player")


func _setup_player() -> void:
	# Get current floor from tower
	var current_floor = tower.get_current_floor()
	if current_floor == null:
		push_error("Match: No current floor loaded")
		return
	
	# PlayerInstance is the actual Player (CharacterBody2D)
	if player == null or not player.is_inside_tree():
		push_error("Match: PlayerInstance not found or not ready")
		return
	
	GameLog.info("Match", "M11 test match ready — player at %s" % player.global_position)
	
	# Give the camera something to clamp to from the floor data
	var camera_component = player.get_node_or_null("CameraComponent")
	if camera_component != null and current_floor.floor_data != null:
		camera_component.set_floor_bounds(current_floor.floor_data.bounds)
	
	# Spawn player at a floor spawn point (or center)
	var spawn_pos: Vector2 = current_floor.get_random_spawn_point()
	player.global_position = spawn_pos
	
	# Listen for floor changes to update camera bounds
	tower.floor_changed.connect(_on_floor_changed)
	
	# Start match clock so debug overlay shows RUNNING.
	GameState.start_match(300.0, 1)
	SignalHub.player_spawned.emit(player, player.global_position)


func _on_floor_changed(new_floor_id: int) -> void:
	var current_floor = tower.get_current_floor()
	if current_floor != null and current_floor.floor_data != null:
		var camera_component = player.get_node_or_null("CameraComponent")
		if camera_component != null:
			camera_component.set_floor_bounds(current_floor.floor_data.bounds)
		
		# Re-spawn player at new floor's spawn point
		var spawn_pos: Vector2 = current_floor.get_random_spawn_point()
		player.global_position = spawn_pos
		
		GameLog.info("Match", "Moved to Floor %d" % new_floor_id)


func _exit_tree() -> void:
	GameState.reset()
