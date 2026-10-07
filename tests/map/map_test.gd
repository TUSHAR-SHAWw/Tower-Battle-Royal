extends TestCase


func test_map_resource_tracks_all_fifty_floors() -> void:
	var map := load("res://resources/map/tower_map.tres") as MapResource
	assert_not_null(map)
	if map == null:
		return
	map.synchronize_floor_count(50)
	assert_eq(map.total_floors, 50)
	assert_eq(map.floor_positions.size(), 50)
	assert_eq(map.get_connected_floors(25), [24, 26])
	assert_true(map.validate().is_empty(), "the synchronized 50-floor tower map should validate")


func test_minimap_and_world_map_build_fifty_floor_rows() -> void:
	var map := load("res://resources/map/tower_map.tres") as MapResource
	var minimap := MinimapUI.new()
	minimap.map_resource = map
	add_child(minimap)
	var world_map := WorldMapUI.new()
	world_map.map_resource = map
	add_child(world_map)
	await get_tree().process_frame
	assert_eq(minimap._row_labels.size(), 50, "minimap should cover the complete tower")
	assert_eq(world_map._rows.size(), 50, "world map should cover the complete tower")
	var minimap_panel := minimap.get_node("PixelArtCanvas/TowerMinimap") as Control
	assert_less(minimap_panel.size.x, 240.0, "the in-match tower map should use a compact width")
	assert_less(minimap_panel.size.y, 290.0, "the in-match tower map should use a compact height")
	assert_false(minimap.get_node("PixelArtCanvas").find_children("*", "Node", true, false).is_empty(),
		"map display should be assembled from regular scene/control nodes")
	minimap.queue_free()
	world_map.queue_free()
	await get_tree().process_frame


func test_platform_shuttles_between_floor_stops_and_reverses() -> void:
	var packed := load("res://scenes/tower/CentralPlatform.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var platform := packed.instantiate() as CentralPlatformController
	assert_not_null(platform)
	if platform == null:
		return
	add_child(platform)
	platform.configure_route(50, 1)
	assert_eq(platform.floor_stops.size(), 50)
	assert_eq(platform.get_display_floor(), 1)

	platform.configure_route(3, 1)
	platform.descent_speed = 100000.0
	platform._speed = platform.descent_speed
	platform.pause_duration = 0.0
	var stops: Array[int] = []
	platform.arrived_at_floor.connect(func(floor_id: int) -> void:
		stops.append(floor_id)
	)
	platform.start_descent()
	for _frame in range(30):
		await get_tree().physics_frame
		if stops.size() >= 3:
			break
	assert_eq(stops, [2, 3, 2], "lift should reverse at floor 3 and return to floor 2")
	assert_eq(platform.get_direction_name(), "down")
	assert_true(platform.get_node("Body/CollisionShape2D").shape != null,
		"the sprite elevator deck needs a real solid collision surface")
	assert_eq(platform.get_node("Visual").find_children("DeckTile_*", "Sprite2D", false, false).size(), 15,
		"the central elevator should be assembled from repeated asset sprites")
	assert_not_null(platform.get_node("Visual/DeckTile_00").texture,
		"the elevator deck should use a bundled tile texture")
	platform.queue_free()
	await get_tree().process_frame


func test_player_boards_and_is_carried_by_platform() -> void:
	var packed := load("res://scenes/tower/CentralPlatform.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var platform := packed.instantiate() as CentralPlatformController
	assert_not_null(platform)
	if platform == null:
		return
	platform.configure_route(3, 1)
	add_child(platform)

	var player := CharacterBody2D.new()
	player.name = "LiftRider"
	player.add_to_group(&"player")
	player.collision_layer = 2
	player.collision_mask = 0
	var player_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	player_shape.shape = circle
	player.add_child(player_shape)
	add_child(player)
	player.global_position = platform.global_position + Vector2(0.0, -14.0)

	for _frame in range(3):
		await get_tree().physics_frame
	assert_true(platform.get_players().has(player),
		"the platform sensor should register a player body boarding the deck")

	var rider_y_before := player.global_position.y
	var platform_y_before := platform.global_position.y
	platform.descent_speed = 100000.0
	platform._speed = platform.descent_speed
	platform.start_descent()
	platform._physics_process(0.25)
	var platform_delta := platform.global_position.y - platform_y_before
	assert_less(platform_delta, 0.0, "the platform should travel toward the next floor")
	assert_almost_eq(player.global_position.y - rider_y_before, platform_delta,
		"registered riders should move by the same vertical delta as the deck")
	assert_eq(platform.get_current_floor(), 2, "rider should arrive with the lift at the next floor")

	player.global_position.x += 1000.0
	for _frame in range(3):
		await get_tree().physics_frame
	assert_false(platform.get_players().has(player),
		"the platform should unregister a player who leaves its boarding sensor")

	platform.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_production_player_rides_platform_to_next_floor() -> void:
	var platform_scene := load("res://scenes/tower/CentralPlatform.tscn") as PackedScene
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	assert_not_null(platform_scene)
	assert_not_null(player_scene)
	if platform_scene == null or player_scene == null:
		return
	var platform := platform_scene.instantiate() as CentralPlatformController
	var player := player_scene.instantiate() as Player
	assert_not_null(platform)
	assert_not_null(player)
	if platform == null or player == null:
		return

	platform.configure_route(2, 1)
	platform.pause_duration = 0.0
	add_child(platform)
	add_child(player)
	player.global_position = platform.global_position + Vector2(0.0, -14.0)

	var boarded := false
	for _frame in range(30):
		await get_tree().physics_frame
		if player.is_on_floor() and platform.get_players().has(player):
			boarded = true
			break
	assert_true(boarded, "the production player should land on and register with the lift")
	if boarded:
		platform.descent_speed = 3600.0
		platform._speed = platform.descent_speed
		platform.start_descent()
		for _frame in range(60):
			await get_tree().physics_frame
			if platform.get_current_floor() == 2:
				break
		assert_eq(platform.get_current_floor(), 2, "lift should reach its next production floor stop")
		assert_true(player.is_on_floor(), "production player should remain grounded on the moving deck")
		assert_almost_eq(
			player.global_position.y - platform.global_position.y,
			-14.0,
			"production player should keep its deck-relative height during travel",
			5.0
		)

	platform.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_match_camera_switches_to_tower_tracking_for_lift_riders() -> void:
	var packed := load("res://scenes/main/Match.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var match_scene := packed.instantiate() as Node2D
	add_child(match_scene)
	for _frame in range(5):
		await get_tree().physics_frame

	var player := match_scene.get_node_or_null("PlayerInstance") as Player
	var platform := match_scene.get_node_or_null("CentralPlatform") as CentralPlatformController
	var camera := player.get_node_or_null("CameraComponent") as CameraComponent if player != null else null
	assert_not_null(player)
	assert_not_null(platform)
	assert_not_null(camera)
	if player == null or platform == null or camera == null:
		match_scene.queue_free()
		await get_tree().process_frame
		return

	platform.stop()
	player.global_position = platform.global_position + Vector2(0.0, -14.0)
	for _frame in range(6):
		await get_tree().physics_frame
	assert_true(platform.get_players().has(player), "the match platform sensor should board its player")
	if not platform.get_players().has(player):
		match_scene.queue_free()
		await get_tree().process_frame
		return
	assert_true(camera._platform_tracking, "boarding should enable focused lift camera tracking")
	assert_greater(camera._floor_bounds.size.y, FloorData.DEFAULT_BOUNDS.size.y * 10.0,
		"boarding should extend camera limits across the tower")

	platform.descent_speed = 3600.0
	platform.resume()
	var camera_y_before := camera.camera.global_position.y
	for _frame in range(40):
		await get_tree().physics_frame
		if platform.get_current_floor() == 2:
			break
	assert_eq(platform.get_current_floor(), 2, "the match lift should reach the next stop")
	assert_less(camera.camera.global_position.y, camera_y_before - 5.0,
		"the camera should follow the player upward as the lift changes floors")

	platform.unregister_player(player)
	assert_false(camera._platform_tracking, "leaving the lift should restore room camera tracking")
	assert_almost_eq(camera._floor_bounds.size.y, FloorData.DEFAULT_BOUNDS.size.y,
		"leaving the lift should restore the current floor camera bounds")
	match_scene.queue_free()
	await get_tree().process_frame


func test_floor_backdrop_and_hotbar_use_texture_and_control_nodes() -> void:
	var floor_visual := FloorVisual.new()
	add_child(floor_visual)
	var floor_data := FloorData.new()
	floor_data.bounds = FloorData.DEFAULT_BOUNDS
	floor_data.ambient_color = Color(0.08, 0.18, 0.22, 1.0)
	var floor_theme := load("res://resources/floors/theme_ice.tres") as FloorTheme
	floor_visual.configure_floor(floor_data, floor_theme)
	assert_eq(floor_visual.get_child_count(), 4, "floor backdrop should use editable texture/color nodes")
	assert_ne(MapAssetLibrary.floor_theme_color(floor_data), Color(0.0, 0.0, 0.0, 1.0))

	var inventory := InventoryComponent.new()
	add_child(inventory)
	await get_tree().process_frame
	var hotbar := HotbarUI.new()
	hotbar.inventory = inventory
	add_child(hotbar)
	await get_tree().process_frame
	assert_eq(hotbar._buttons.size(), InventoryComponent.HOTBAR_SIZE,
		"hotbar should have all nine inventory slots")
	assert_less(hotbar.get_hotbar_rect().size.x, 450.0,
		"the hotbar should be compact enough to leave the play area visible")
	assert_less(hotbar.get_hotbar_rect().size.y, 50.0,
		"the hotbar should use a low-profile slot height")
	var item := load("res://resources/items/health_pack.tres") as ItemResource
	inventory.add_item(item, 2)
	assert_not_null(hotbar._icons[0].texture, "inventory items should show bundled sprite icons")
	assert_eq(hotbar._quantities[0].text, "2", "stack counts should be displayed on hotbar slots")

	hotbar.queue_free()
	floor_visual.queue_free()
	inventory.queue_free()
	await get_tree().process_frame


func test_themed_floor_spawns_collectible_shaft_loot() -> void:
	var packed := load("res://scenes/floors/FloorController.tscn") as PackedScene
	var data := load("res://resources/floors/floor_02.tres") as FloorData
	assert_not_null(packed)
	assert_not_null(data)
	if packed == null or data == null:
		return
	var floor := packed.instantiate() as FloorController
	floor.floor_data = data
	add_child(floor)
	await get_tree().process_frame
	(floor.get_node("EnemySpawner") as EnemySpawner).stop_spawning()
	var pickups := floor.find_children("ShaftLoot_*", "ItemPickup", true, false)
	assert_eq(pickups.size(), 2, "themed floors should place two real pickups by the shaft lip")
	for pickup_node: Node in pickups:
		var pickup := pickup_node as ItemPickup
		assert_not_null(pickup.item, "shaft loot should resolve to an inventory item resource")
		assert_not_null(pickup.get_node("ItemIcon").texture, "shaft loot should display a texture sprite")
	floor.queue_free()
	await get_tree().process_frame


func test_map_and_loot_visuals_use_nodes_and_texture_assets() -> void:
	var paths := [
		"res://scripts/tower/CentralPlatformVisual.gd",
		"res://scripts/tower/TravelPortal.gd",
		"res://scripts/map/MinimapUI.gd",
		"res://scripts/map/WorldMapUI.gd",
		"res://scripts/ui/HotbarUI.gd",
		"res://scripts/loot/ItemPickup.gd",
		"res://scripts/loot/LootChest.gd",
		"res://scripts/floors/FloorVisual.gd",
		"res://scripts/floors/PropVisual.gd",
	]
	for path: String in paths:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), "%s should be readable" % path)
		for forbidden: String in ["func _draw", "draw_circle(", "draw_rect(", "draw_texture(", "draw_string(", "draw_line("]:
			assert_false(source.contains(forbidden), "%s must not use %s for map visuals" % [path, forbidden])

	var health_pack := load("res://resources/items/health_pack.tres") as ItemResource
	assert_not_null(MapAssetLibrary.item_texture(health_pack),
		"item placeholders should resolve to bundled sprite textures")
