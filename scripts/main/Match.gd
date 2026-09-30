extends Node2D

## M16 test match: TowerController with floors, central platform, player.
##
## This match scene wires:
## - TowerController (loads floors from tower_definition.tres)
## - CentralPlatformController (descending central platform)
## - Player (local single player)

@onready var player: Node = $PlayerInstance
@onready var tower: TowerController = $TowerController
@onready var central_platform: CentralPlatformController = $CentralPlatform

@export var spawn_floor: int = 1

var _travel_portal: TravelPortal = null
var _player_body: Node = null


func _get_player_body() -> Node:
	## The Player.tscn is instanced under PlayerInstance, so the actual
	## CharacterBody2D is at PlayerInstance/Player. Find it once.
	if _player_body != null:
		return _player_body
	for child in player.get_children():
		if child is CharacterBody2D or child.has_method("get_aim_direction"):
			_player_body = child
			break
	return _player_body


func _ready() -> void:
	if tower == null or not tower.is_inside_tree():
		push_error("Match: TowerController not found or not ready")
		return

	if central_platform == null or not central_platform.is_inside_tree():
		push_error("Match: CentralPlatform not found or not ready")
		return

	call_deferred("_setup_player")


func _setup_player() -> void:
	var current_floor := tower.get_current_floor()
	if current_floor == null:
		push_error("Match: No current floor loaded")
		return

	var body := _get_player_body()
	if body == null:
		push_error("Match: Player body not found under PlayerInstance")
		return

	GameLog.info("Match", "Tower match ready — player at floor %d" % tower.get_current_floor_id())

	# Give the camera something to clamp to from the floor data
	var camera_component := body.get_node_or_null("CameraComponent")
	if camera_component != null and current_floor.floor_data != null:
		camera_component.set_floor_bounds(current_floor.floor_data.bounds)
		print("[DEBUG] Match: Camera bounds set to: %s" % current_floor.floor_data.bounds)
		var cam := body.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			print("[DEBUG] Match: Camera2D global_position: %s, zoom: %s" % [cam.global_position, cam.zoom])

	# Spawn player at a floor spawn point (or center)
	var spawn_pos: Vector2 = current_floor.get_random_spawn_point()
	body.global_position = spawn_pos

	print("[DEBUG] Match: Player spawn location: %s (floor bounds: %s)" % [spawn_pos, current_floor.floor_data.bounds])
	print("[DEBUG] Match: Camera component: %s, Camera2D: %s" % [camera_component, body.get_node_or_null("Camera2D")])

	GameLog.info("Match", "Player spawned at %s, camera=%s" % [spawn_pos, body.get_node_or_null("Camera2D")])

	# Initialize minimap and world map
	var minimap := body.get_node_or_null("MinimapUI")
	var world_map := body.get_node_or_null("WorldMapUI")
	if minimap != null:
		minimap.set_current_floor(spawn_floor)
		minimap.mark_floor_explored(spawn_floor)
	if world_map != null:
		world_map.set_current_floor(spawn_floor)
		world_map.mark_floor_explored(spawn_floor)

	# Find the travel portal spawned by the floor
	_travel_portal = _find_travel_portal()
	if _travel_portal != null:
		_travel_portal.activated.connect(_on_portal_activated)

	# Listen for floor changes
	tower.floor_changed.connect(_on_floor_changed)

	# Start the central platform descent
	central_platform.start_descent()

	# Start match clock so debug overlay shows RUNNING.
	GameState.start_match(300.0, 1)
	SignalHub.player_spawned.emit(body, body.global_position)


func _find_travel_portal() -> TravelPortal:
	var current_floor := tower.get_current_floor()
	if current_floor == null:
		return null
	return current_floor.get_node_or_null("TravelPortal") as TravelPortal


func _on_floor_changed(_new_floor_id: int) -> void:
	print("[DEBUG] Match: Floor changed to %d" % _new_floor_id)
	var current_floor := tower.get_current_floor()
	if current_floor == null or current_floor.floor_data == null:
		return

	var body := _get_player_body()
	if body == null:
		return

	var camera_component := body.get_node_or_null("CameraComponent")
	if camera_component != null:
		camera_component.set_floor_bounds(current_floor.floor_data.bounds)

	# Update platform stops to only include unvisited floors
	var stops: Array[int] = []
	for fd: TowerData in tower.tower_data:
		if fd.floor_id >= _new_floor_id:
			stops.append(fd.floor_id)
	central_platform.floor_stops = stops

	# Re-spawn player at new floor's spawn point
	var spawn_pos: Vector2 = current_floor.get_random_spawn_point()
	body.global_position = spawn_pos
	print("[DEBUG] Match: Player respawned at floor %d, position: %s" % [_new_floor_id, spawn_pos])

	# Update maps
	var minimap := body.get_node_or_null("MinimapUI")
	var world_map := body.get_node_or_null("WorldMapUI")
	if minimap != null:
		minimap.set_current_floor(_new_floor_id)
		minimap.mark_floor_explored(_new_floor_id)
	if world_map != null:
		world_map.set_current_floor(_new_floor_id)
		world_map.mark_floor_explored(_new_floor_id)

	# Re-find the portal on the new floor
	_travel_portal = _find_travel_portal()
	if _travel_portal != null:
		_travel_portal.activated.connect(_on_portal_activated)

	GameLog.info("Match", "Moved to Floor %d" % _new_floor_id)


func _on_portal_activated(body: Node2D) -> void:
	if body.is_in_group(&"player") and body == _player_body:
		if _travel_portal != null:
			var target := _travel_portal.target_floor
			if target > 0:
				tower.start_travel(target)


func _exit_tree() -> void:
	GameState.reset()
