extends Node2D

## M2 test match: one floor with FloorController, one player.
##
## Floor is instanced in code (Godot 4 scene instancing via .tscn property is unreliable).

@onready var player: Node = $PlayerInstance

@export var floor_data_resource: Resource = load("res://resources/floors/floor_01.tres")
@export var floor_scene: PackedScene = load("res://scenes/floors/FloorController.tscn")

var floor_instance: Node2D


func _ready() -> void:
	# Instance the floor scene
	if floor_scene == null:
		push_error("Match: floor_scene not assigned")
		return
	
	floor_instance = floor_scene.instantiate() as Node2D
	add_child(floor_instance)
	
	# FloorInstance IS the FloorController (Node2D with FloorController script)
	if floor_instance == null or not floor_instance.is_inside_tree():
		push_error("Match: FloorInstance not found or not ready")
		return

	# Assign floor data to the floor controller
	if floor_data_resource != null and floor_instance.has_method("set_floor_data"):
		floor_instance.set_floor_data(floor_data_resource as FloorData)
		GameLog.info("Match", "Floor %s loaded" % (floor_instance.floor_data.display_name if floor_instance.floor_data else "unknown"))

	# PlayerInstance is the actual Player (CharacterBody2D)
	if player == null or not player.is_inside_tree():
		push_error("Match: PlayerInstance not found or not ready")
		return

	GameLog.info("Match", "M2 test match ready — player at %s" % player.global_position)

	# Give the camera something to clamp to from the floor data
	var camera_component = player.get_node_or_null("CameraComponent")
	if camera_component != null and floor_instance.floor_data != null:
		camera_component.set_floor_bounds(floor_instance.floor_data.bounds)

	# Spawn player at a floor spawn point (or center)
	var spawn_pos: Vector2 = floor_instance.get_random_spawn_point()
	player.global_position = spawn_pos

	# Start match clock so debug overlay shows RUNNING.
	GameState.start_match(300.0, 1)
	SignalHub.player_spawned.emit(player, player.global_position)


func _exit_tree() -> void:
	GameState.reset()