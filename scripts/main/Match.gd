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
	## The Player.tscn is instanced under PlayerInstance. When instanced,
	## the root CharacterBody2D is flattened, so PlayerInstance IS the body.
	if _player_body != null:
		return _player_body
	# Use PlayerInstance directly — it has all the Player's children.
	_player_body = player
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

	# Give the camera something to clamp to from the floor data, and size the
	# character against the floor it is about to stand on.
	var camera_component := body.get_node_or_null("CameraComponent") as CameraComponent
	if camera_component != null and current_floor.floor_data != null:
		var bounds := tower.get_floor_world_rect(current_floor, tower.get_current_floor_id())
		camera_component.set_floor_bounds(bounds)
		print("[DEBUG] Match: Camera bounds set to: %s" % bounds)
	_apply_floor_scale(body, current_floor)

	# Spawn the player on the floor's ground surface, not floating mid-room.
	var spawn_pos := Vector2.ZERO
	if current_floor.has_method("get_player_spawn_position"):
		spawn_pos = current_floor.get_player_spawn_position() as Vector2
	else:
		spawn_pos = current_floor.get_random_spawn_point()
	body.global_position = spawn_pos
	body.velocity = Vector2.ZERO

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
	_set_travel_portal(_find_travel_portal())

	# Listen for floor changes
	tower.floor_changed.connect(_on_floor_changed)

	# Start the central platform descent
	central_platform.start_descent()

	# Start match clock so debug overlay shows RUNNING.
	GameState.start_match(300.0, 1)
	SignalHub.player_spawned.emit(body, body.global_position)


## Points the match at a floor's portal, replacing any previous subscription.
func _set_travel_portal(portal: TravelPortal) -> void:
	if _travel_portal == portal:
		return
	if _travel_portal != null and is_instance_valid(_travel_portal) \
			and _travel_portal.activated.is_connected(_on_portal_activated):
		_travel_portal.activated.disconnect(_on_portal_activated)
	_travel_portal = portal
	if _travel_portal != null and not _travel_portal.activated.is_connected(_on_portal_activated):
		_travel_portal.activated.connect(_on_portal_activated)


## Sizes the player's sprite from the loaded floor's height.
##
## The character is drawn at FloorData.PLAYER_HEIGHT_RATIO of the floor height, so
## the two are always in proportion: a floor resize keeps the player looking like a
## person in a room rather than a dot on a wall.
func _apply_floor_scale(body: Node, floor: Node) -> void:
	if body == null or floor == null or floor.floor_data == null:
		return
	if body.has_method(&"apply_floor_scale"):
		body.call(&"apply_floor_scale", floor.floor_data.bounds.size.y)


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
		camera_component.set_floor_bounds(tower.get_floor_world_rect(current_floor, _new_floor_id))
	_apply_floor_scale(body, current_floor)

	# Update platform stops to only include unvisited floors
	var stops: Array[int] = []
	for fd: TowerData in tower.tower_data:
		if fd.floor_id >= _new_floor_id:
			stops.append(fd.floor_id)
	central_platform.floor_stops = stops

	# Re-spawn player on the new floor's slab, clear of the central shaft.
	var spawn_pos: Vector2 = current_floor.get_player_spawn_position() if current_floor.has_method(&"get_player_spawn_position") \
		else current_floor.get_random_spawn_point()
	body.global_position = spawn_pos
	body.velocity = Vector2.ZERO
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

	# Snap the camera to the new floor instead of letting it ease across the room,
	# which read as the whole level sliding sideways on every floor change.
	if camera_component != null and camera_component.has_method(&"snap_to_target"):
		camera_component.call(&"snap_to_target")

	# Re-find the portal on the new floor. The old floor (and its portal) is on its
	# way out, so drop the previous connection first — reconnecting every floor
	# change leaked one signal binding per floor and fired the handler repeatedly.
	_set_travel_portal(_find_travel_portal())

	GameLog.info("Match", "Moved to Floor %d" % _new_floor_id)


func _on_portal_activated(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if _travel_portal == null:
		return
	var target := _travel_portal.target_floor
	if target <= 0:
		return
	print("[DEBUG] Match: Portal entered by %s -> starting travel to floor %d" % [body.name, target])
	tower.start_travel(target)


func _exit_tree() -> void:
	GameState.reset()
