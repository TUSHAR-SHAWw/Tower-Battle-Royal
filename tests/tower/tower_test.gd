extends TestCase

## Tests for the tower structure: TowerData, FloorData, and floor sequencing.
## Ensures all 10 floors plus the central platform are properly configured.

class FloorWithData:
	extends Node2D

	var floor_data: FloorData


func test_tower_definition_exists() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	assert_not_null(tower, "tower_definition.tres must exist")

func test_tower_has_ten_floors() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	assert_eq(tower.floors.size(), 50, "tower should have 50 floors")
	assert_eq(tower.total_floors, 50, "total_floors should match the floor list")

func test_tower_floors_are_valid() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	for i: int in tower.floors.size():
		var fd: TowerData = tower.floors[i]
		assert_not_null(fd, "floor %d must not be null" % i)
		var problems := fd.validate()
		assert_true(problems.is_empty(), "floor %d (%s) validation: %s" % [i, fd.display_name, ", ".join(problems)])

func test_central_platform_exists() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var platform := tower.get_central_platform_floor()
	assert_not_null(platform, "central platform floor should exist")
	if platform != null:
		assert_true(platform.is_central_platform, "floor %d should be central platform" % platform.floor_id)

func test_central_platform_index_valid() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	assert_true(tower.central_platform_floor_index >= 0, "central_platform_floor_index must be >= 0")
	assert_true(tower.central_platform_floor_index < tower.floors.size(), "central_platform_floor_index must be < floors.size")

func test_floor_ids_are_sequential() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var ids: Array[int] = tower.get_sorted_floor_ids()
	for i: int in ids.size():
		assert_eq(ids[i], i + 1, "floor id at index %d should be %d" % [i, i + 1])

func test_floor_difficulty_scales() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var prev_mod := 0.0
	for i: int in tower.floors.size():
		var fd: TowerData = tower.floors[i]
		if fd == null:
			continue
		if i > 0:
			assert_greater(fd.difficulty_modifier, prev_mod, "floor %d difficulty should increase" % fd.floor_id)
		prev_mod = fd.difficulty_modifier

func test_floors_have_travel_targets() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	for fd: TowerData in tower.floors:
		if fd == null:
			continue
		if fd.is_central_platform:
			continue
		var target := int(fd.travel_portal_position.x)
		if fd.floor_id == tower.floors.size():
			continue  # bottom floor has no downward portal
		assert_true(target > 0, "floor %d should have a travel target" % fd.floor_id)

func test_central_platform_has_central_data() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var central_id: int = tower.central_platform_floor_id
	assert_true(central_id >= 1 and central_id <= tower.floors.size(),
		"central platform id %d must be inside the tower" % central_id)
	# is_central_platform lives on the TowerData entry, not on FloorData.
	var central: TowerData = tower.floors[central_id - 1]
	assert_not_null(central, "floor %d must exist" % central_id)
	if central != null:
		assert_true(central.is_central_platform,
			"floor %d should be flagged as the central platform" % central_id)
		assert_eq(central.floor_id, central_id, "central floor id must line up")

func test_floors_have_unique_ids() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var seen: Dictionary[int, bool] = {}
	for fd: TowerData in tower.floors:
		if fd == null:
			continue
		assert_false(seen.has(fd.floor_id), "floor_id %d is duplicated" % fd.floor_id)
		seen[fd.floor_id] = true


func test_deleted_floor_disables_collision_bodies_in_its_container() -> void:
	var floor_scene := load("res://scenes/floors/FloorController.tscn") as PackedScene
	assert_not_null(floor_scene)
	if floor_scene == null:
		return

	var floor := floor_scene.instantiate() as FloorController
	add_child(floor)
	await get_tree().physics_frame

	var collision_container := floor.get_node("Collision") as Node2D
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.collision_mask = PhysicsLayers.PLAYER
	collision_container.add_child(wall)
	floor._state = FloorData.FloorState.DELETED
	floor._update_visual_state()
	await get_tree().physics_frame

	assert_eq(wall.collision_layer, 0, "deletion should disable the wall's collision layer")
	assert_eq(wall.collision_mask, 0, "deletion should disable the wall's collision mask")
	assert_false((floor.get_node("Ground") as TileMapLayer).collision_enabled,
		"deletion should disable ground tile collisions")

	floor.queue_free()
	await get_tree().process_frame


func test_travel_portal_defers_initial_physics_flags() -> void:
	var portal := TravelPortal.new()
	portal.activation_radius = 96.0
	add_child(portal)
	await get_tree().physics_frame

	assert_true(portal.monitoring, "portal should monitor after deferred initialization")
	assert_false(portal.monitorable, "portal should not be detected by other areas")
	var shape := portal.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(shape, "portal collision shape should be attached during deferred initialization")
	if shape != null and shape.shape is CircleShape2D:
		assert_eq((shape.shape as CircleShape2D).radius, 96.0,
			"deferred shape should respect the configured activation radius")

	portal.queue_free()
	await get_tree().process_frame


func test_production_floor_configures_enemy_types_without_spawning_before_data() -> void:
	var floor_scene := load("res://scenes/floors/FloorController.tscn") as PackedScene
	assert_not_null(floor_scene)
	if floor_scene == null:
		return

	var floor := floor_scene.instantiate() as FloorController
	add_child(floor)
	await get_tree().process_frame

	assert_greater(floor.enemy_types.size(), 0, "production floors need configured enemies")
	assert_eq(floor.get_node("EnemySpawner").get_enemies_alive(), 0,
		"unconfigured floors should wait for floor data before starting waves")

	floor.queue_free()
	await get_tree().process_frame


func test_floor_world_positions_include_tower_offset() -> void:
	var floor_scene := load("res://scenes/floors/FloorController.tscn") as PackedScene
	assert_not_null(floor_scene)
	if floor_scene == null:
		return

	var floor := floor_scene.instantiate() as FloorController
	floor.position = Vector2(0.0, -FloorData.DEFAULT_BOUNDS.size.y)
	add_child(floor)
	await get_tree().process_frame
	floor.floor_data = FloorData.new()
	floor.floor_data.floor_id = 2

	var spawn_position := floor.get_player_spawn_position()
	assert_almost_eq(spawn_position.y, floor.global_position.y - 84.0,
		"spawn positions must include the floor's tower-space offset")
	assert_true(floor.is_position_inside(spawn_position),
		"world-space spawn positions should be inside their owning floor")

	floor.set_target_floor(2)
	var portal := floor.get_node("TravelPortal") as TravelPortal
	assert_not_null(portal)
	assert_almost_eq(portal.global_position.y, floor.global_position.y - 540.0,
		"portal world position should include its floor's tower-space offset")

	floor.queue_free()
	await get_tree().process_frame


func test_floor_world_rect_includes_canonical_bounds_and_tower_offset() -> void:
	var floor := FloorWithData.new()
	floor.position = Vector2(0.0, -FloorData.DEFAULT_BOUNDS.size.y)
	floor.floor_data = FloorData.new()
	floor.floor_data.floor_id = 2
	add_child(floor)
	await get_tree().process_frame

	var tower := TowerController.new()
	add_child(tower)
	var world_rect := tower.get_floor_world_rect(floor, 2)
	assert_eq(world_rect, Rect2(-3200.0, -2160.0, 6400.0, 1080.0),
		"camera bounds should translate the canonical floor rectangle into tower space")

	tower.queue_free()
	floor.queue_free()
	await get_tree().process_frame


func test_floor_background_decor_stays_sparse() -> void:
	var tile_set := TowerTileSetBuilder.build()
	assert_not_null(tile_set, "production floor tileset should build")
	if tile_set == null:
		return

	var ground := TileMapLayer.new()
	var decor := TileMapLayer.new()
	add_child(ground)
	add_child(decor)
	FloorTileLayout.populate(
		ground,
		decor,
		tile_set,
		FloorData.DEFAULT_BOUNDS,
		7919,
		TowerTileSetBuilder.source_for_theme("mountain"),
		0.0
	)

	assert_greater(ground.get_used_cells().size(), 1000,
		"the sparse visual pass must preserve the solid floor layout")
	assert_in_range(decor.get_used_cells().size(), 1.0, 100.0,
		"background decor should be a few accents, not hundreds of repeated pixels")

	ground.queue_free()
	decor.queue_free()
	await get_tree().process_frame


func test_authored_8px_floor_tiles_render_at_three_times() -> void:
	var floor := FloorController.new()
	var layer := TileMapLayer.new()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(PixelArtScale.TILE_SOURCE_SIZE, PixelArtScale.TILE_SOURCE_SIZE)
	layer.tile_set = tile_set
	floor._apply_authored_tile_scale(layer)

	assert_eq(layer.scale, PixelArtScale.tilemap_scale(),
		"8x8 authored tile layers should be scaled for the 3x output")
	assert_almost_eq(
		float(tile_set.tile_size.x) * layer.scale.x
			* PixelArtScale.CAMERA_ZOOM * PixelArtScale.DISPLAY_SCALE,
		PixelArtScale.TILE_SCREEN_SIZE,
		"an 8px cell should occupy 24 screen pixels"
	)

	var legacy_layer := TileMapLayer.new()
	var legacy_tile_set := TileSet.new()
	legacy_tile_set.tile_size = Vector2i(18, 18)
	legacy_layer.tile_set = legacy_tile_set
	legacy_layer.scale = Vector2(2.0, 2.0)
	floor._apply_authored_tile_scale(legacy_layer)
	assert_eq(legacy_layer.scale, Vector2(2.0, 2.0),
		"non-8px atlas layers should retain their authored scale")

	floor.free()
	layer.free()
	legacy_layer.free()


func test_travel_places_next_floor_at_its_tower_height() -> void:
	var floor_root := Node2D.new()
	var floor_scene := PackedScene.new()
	assert_eq(floor_scene.pack(floor_root), OK)
	floor_root.free()

	var first_data := TowerData.new()
	first_data.floor_id = 1
	first_data.floor_scene = floor_scene
	first_data.travel_portal_position = Vector2(2.0, 0.0)
	var second_data := TowerData.new()
	second_data.floor_id = 2
	second_data.floor_scene = floor_scene

	var tower := TowerController.new()
	tower.tower_data = [first_data, second_data]
	tower.initial_floor = 1
	add_child(tower)
	await get_tree().process_frame

	tower.start_travel(2)
	assert_not_null(tower._next_floor)
	if tower._next_floor != null:
		assert_eq((tower._next_floor as Node2D).position.y, -FloorData.DEFAULT_BOUNDS.size.y,
			"preloaded floor should be stacked above the departing floor")

	tower._finish_deletion(1)
	assert_eq(tower.get_current_floor_id(), 2)
	assert_eq((tower.get_current_floor() as Node2D).position.y, -FloorData.DEFAULT_BOUNDS.size.y)

	tower.queue_free()
	await get_tree().process_frame


func test_portal_travel_finishes_when_old_floor_reaches_deleted_state() -> void:
	var floor_scene := load("res://scenes/floors/FloorController.tscn") as PackedScene
	assert_not_null(floor_scene, "production floor scene must be available")
	if floor_scene == null:
		return

	var first_floor_data := FloorData.new()
	first_floor_data.floor_id = 1
	var second_floor_data := FloorData.new()
	second_floor_data.floor_id = 2

	var first_data := TowerData.new()
	first_data.floor_id = 1
	first_data.floor_scene = floor_scene
	first_data.floor_data = first_floor_data
	first_data.travel_portal_position = Vector2(2.0, 0.0)
	var second_data := TowerData.new()
	second_data.floor_id = 2
	second_data.floor_scene = floor_scene
	second_data.floor_data = second_floor_data

	var tower := TowerController.new()
	tower.tower_data = [first_data, second_data]
	tower.deletion_delay = 0.05
	var deleted_floors: Array[int] = []
	tower.floor_deleted.connect(func(floor_id: int) -> void: deleted_floors.append(floor_id))
	add_child(tower)
	await get_tree().process_frame

	var departing_floor := tower.get_current_floor() as FloorController
	assert_not_null(departing_floor, "tower should load its initial floor")
	if departing_floor == null:
		tower.queue_free()
		return
	var departing_states: Array[int] = []
	departing_floor.state_changed.connect(func(state: int) -> void: departing_states.append(state))
	departing_floor._warning_duration = 0.02
	departing_floor._collapse_duration = 0.02
	departing_floor.get_node("EnemySpawner").stop_spawning()

	var portal := departing_floor.get_node_or_null("TravelPortal") as TravelPortal
	assert_not_null(portal, "floor travel target should create an actual portal")
	if portal == null:
		tower.queue_free()
		return
	portal.activated.connect(func(_player: Node) -> void: tower.start_travel(portal.target_floor))

	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	portal._try_activate(player)
	assert_eq(tower.get_current_floor_id(), 1, "floor switch should wait until the departing floor is deleted")
	assert_not_null(tower._next_floor, "portal activation should preload its destination")
	if tower._next_floor != null:
		tower._next_floor.get_node("EnemySpawner").stop_spawning()

	await get_tree().physics_frame
	assert_true(departing_floor.get_state() != FloorData.FloorState.DELETED,
		"the deletion delay should leave the old floor in place initially")

	for _frame: int in range(120):
		if not deleted_floors.is_empty():
			break
		await get_tree().physics_frame

	assert_eq(deleted_floors, [1], "travel should delete the departing floor once")
	assert_eq(tower.get_current_floor_id(), 2, "travel should complete onto the portal's destination")
	assert_true(departing_states.has(FloorData.FloorState.DELETED),
		"tower should wait for the floor's complete warning/collapse sequence")

	player.queue_free()
	tower.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
