extends Node2D
class_name FloorController

## Controls a single floor instance.
##
## The floor scene contains:
##   - Visual (background, walls, props)
##   - Collision (walls, boundaries)
##   - Spawn points (players, loot)
##   - State machine (ACTIVE → WARNING → COLLAPSING → DELETED)
##   - EnemySpawner (wave-based enemy spawning)
##
## Only one floor is loaded at a time. The TowerController swaps floors
## by instancing the FloorController scene with a different FloorData.

signal state_changed(new_state: int)
signal player_entered(player: Node)
signal player_exited(player: Node)

@export var floor_data: FloorData
@export var enemy_types: Array[EnemyResource] = []
@export var is_boss_floor: bool = false
@export var boss_data: BossData = null
@export var target_floor: int = 0  # 0 = no portal, >0 = target floor for travel

var _state: int = FloorData.FloorState.ACTIVE
var _state_machine: StateMachine = null
var _warning_timer: float = 0.0
var _collapse_timer: float = 0.0
var _warning_duration: float = 10.0   # seconds of warning before collapse
var _collapse_duration: float = 5.0   # seconds of collapse animation

# Visual nodes
@onready var _visual: Node2D = $Visual
@onready var _decor_tiles: TileMapLayer = $Decor
@onready var _ground_tiles: TileMapLayer = $Ground
@onready var _collision: Node2D = $Collision
@onready var _spawn_points: Node2D = $SpawnPoints
@onready var _enemy_spawner: Node = $EnemySpawner

## Shared TileSet built from the Kenney packs in assets/. Floors reference it so
## the art can be re-pointed in one place.
static var _shared_tile_set: TileSet = null

var _current_floor: int = 1
var _travel_portal: TravelPortal = null


func _ready() -> void:
	# Floor identity must be known before anything reads it. EnemySpawner's wave
	# sizes and the deletion state machine both scale off `_current_floor`, and
	# `_configure_from_data()` — which is what sets it — did not run until after
	# the spawner was configured, so every floor spawned floor-1 sized waves.
	_apply_floor_identity()

	_setup_state_machine()

	# Set initial state
	if floor_data != null:
		_state = floor_data.initial_state
		_configure_from_data()
	else:
		_state = FloorData.FloorState.ACTIVE

	_update_visual_state()

	print("[DEBUG] FloorController: Floor %d ready, bounds: %s, spawn points: %d" % [
		floor_data.floor_id if floor_data else -1,
		floor_data.bounds if floor_data else "null",
		_spawn_points.get_child_count() if _spawn_points != null else 0
	])

	_build_walls()
	_build_loot_lip()

	# Setup enemy spawner
	var spawner := _enemy_spawner as EnemySpawner
	if spawner != null:
		spawner.enemy_types = enemy_types
		spawner.floor_controller = self
		spawner.base_wave_count = 3 + _current_floor
		spawner.enemies_per_wave = 4 + _current_floor
		spawner.wave_interval = max(5.0, 15.0 - _current_floor)

		# Connect signals
		spawner.wave_started.connect(_on_wave_started)
		spawner.wave_completed.connect(_on_wave_completed)
		spawner.all_waves_completed.connect(_on_all_waves_completed)
		spawner.enemy_spawned.connect(_on_enemy_spawned)

		if is_boss_floor and boss_data != null:
			# Setup boss instead of waves
			_setup_boss()
		else:
			print("[DEBUG] FloorController: Floor %d starting enemy spawning (waves: %d, enemies/wave: %d, interval: %.1f)" % [_current_floor, spawner.base_wave_count, spawner.enemies_per_wave, spawner.wave_interval])
			spawner.start_spawning(_current_floor)


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

	# Art direction for this storey. The theme's ambient colour wins so each
	# floor reads distinctly as the player climbs the tower.
	if floor_data.theme != null and _visual != null and "theme" in _visual:
		_visual.set("theme", floor_data.theme)

	_build_tile_layers()

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
	
	# Set floor ID for spawner
	_apply_floor_identity()


## Copies the identity fields out of FloorData. Safe to call before or after the
## visual/collision configure pass, so _ready() can call it early.
func _apply_floor_identity() -> void:
	if floor_data != null:
		_current_floor = floor_data.floor_id


## Builds (once) the placeholder tile layout for this floor.
##
## Existing cells are preserved so hand-painted tiles in the editor are never
## wiped. Regenerating only happens when a floor has no ground at all.
func _build_tile_layers() -> void:
	if _ground_tiles == null or floor_data == null:
		return
	if _ground_tiles.get_used_cells().size() > 0:
		return  # Already painted — leave the artist's work alone.

	if _shared_tile_set == null:
		_shared_tile_set = TowerTileSetBuilder.build()
	if _shared_tile_set == null:
		return

	# Alternate themes so adjacent floors do not look identical.
	# Paint the tiles from the art that matches this storey's theme, so a volcano
	# floor and an ice floor are visibly different.
	var theme := TowerTileSetBuilder.source_for_theme(floor_data.theme_name)

	# The bottom storey must be sealed: an open shaft there would drop the player
	# out of the world, since there is nothing below floor 1 to catch them.
	var is_lowest := floor_data.floor_id <= 1
	var shaft := 0.0 if is_lowest else floor_data.shaft_width

	FloorTileLayout.populate(
		_ground_tiles,
		_decor_tiles,
		_shared_tile_set,
		floor_data.bounds,
		floor_data.floor_id * 7919,
		theme,
		shaft
	)

	# Draw order: FloorVisual's opaque background rect is z 0, the player is z 10.
	# Tiles must sit between them or the background hides them completely.
	_ground_tiles.z_index = 2
	_ground_tiles.z_as_relative = false
	_decor_tiles.z_index = 1
	_decor_tiles.z_as_relative = false


## Y coordinate of the top surface of the floor's ground tiles, in world space.
##
## Used to spawn the player standing on the floor instead of dropping them from
## the middle of the room. Returns null when the floor has no ground tiles.
func get_ground_surface_y() -> Variant:
	if _ground_tiles == null:
		return null
	var used := _ground_tiles.get_used_cells()
	if used.is_empty():
		return null
	# The walkable surface is the top edge of the slab, i.e. the lowest row of
	# solid cells. Using max() over every cell would land on the slab's underside.
	var lowest_row := -2147483647
	for cell: Vector2i in used:
		lowest_row = maxi(lowest_row, cell.y)
	# The slab is several rows thick, so measure from its top, not its bottom.
	var surface_row := lowest_row - (_slab_rows() - 1) if _slab_rows() > 1 else lowest_row
	return _ground_tiles.map_to_local(Vector2i(0, surface_row)).y


## Number of solid rows making up the slab on this floor.
func _slab_rows() -> int:
	return FloorTileLayout.SLAB_ROWS


## World position where a player should appear: standing on the slab, clear of the
## shaft so they never spawn already falling down it.
func get_player_spawn_position() -> Vector2:
	return get_random_ground_position(true)


## A random walkable point on the slab, avoiding the central shaft.
##
## `away_from_shaft` pushes the choice to either side of the hole, which is what
## both player and enemy spawning want: nobody should start over the drop.
func get_random_ground_position(away_from_shaft: bool = true) -> Vector2:
	var bounds := floor_data.bounds if floor_data != null else FloorData.DEFAULT_BOUNDS
	var surface: Variant = get_ground_surface_y()
	var surface_y: float = float(surface) if surface != null else bounds.position.y + bounds.size.y - 60.0

	var shaft_half := _shaft_half_width()
	var margin := 160.0
	var y := surface_y - 24.0  # lift by the actor radius so the body rests on top

	if not away_from_shaft or shaft_half <= 0.0:
		return Vector2(randf_range(bounds.position.x + margin, bounds.position.x + bounds.size.x - margin), y)

	# Pick a side, then a free x on that side.
	var left_min := bounds.position.x + margin
	var left_max := bounds.position.x + bounds.size.x * 0.5 - shaft_half - margin
	var right_min := bounds.position.x + bounds.size.x * 0.5 + shaft_half + margin
	var right_max := bounds.position.x + bounds.size.x - margin

	var chosen: float
	if left_max > left_min and (right_max <= right_min or randf() < 0.5):
		chosen = randf_range(left_min, left_max)
	elif right_max > right_min:
		chosen = randf_range(right_min, right_max)
	else:
		# Floor is narrower than the shaft plus margins; fall back to the edges.
		chosen = bounds.position.x + margin if randf() < 0.5 else bounds.position.x + bounds.size.x - margin
	return Vector2(chosen, y)


## Half the width of the central shaft opening, in pixels (0 when disabled).
func _shaft_half_width() -> float:
	if floor_data == null:
		return FloorData.DEFAULT_SHAFT_WIDTH * 0.5
	return floor_data.shaft_width * 0.5


## True when `position` is over the shaft opening rather than the slab.
func is_over_shaft(position: Vector2) -> bool:
	if floor_data == null:
		return false
	var bounds := floor_data.bounds
	var shaft_half := _shaft_half_width()
	if shaft_half <= 0.0:
		return false
	var center_x := bounds.position.x + bounds.size.x * 0.5
	return absf(position.x - center_x) < shaft_half


## World x of the shaft opening's centre.
func shaft_center_x() -> float:
	var bounds := floor_data.bounds if floor_data != null else FloorData.DEFAULT_BOUNDS
	return bounds.position.x + bounds.size.x * 0.5


## Builds the invisible side walls of the room.
##
## Floors are thousands of pixels wide and the view only shows ~853, so without
## walls the player simply walks off the floor data and keeps going forever — there
## is no geometry out there to stop them. These StaticBody2D walls sit just inside
## the bounds and are tall enough to cover the room plus the slab.
##
## Building is deferred when the physics server is mid-flush, because a floor can be
## constructed from inside a physics callback: travelling through a portal happens
## in `area_entered`, and TowerController loads the next floor straight from there.
## Adding a body (and so a collision shape) during query flushing is illegal, and
## the error it produces left the wall without its collision — a wall that silently
## does not exist.
func _build_walls() -> void:
	if _collision == null or floor_data == null:
		return
	var bounds := floor_data.bounds
	var thickness := 32.0
	# Cover from a little above the ceiling line down past the slab.
	var top := bounds.position.y - 200.0
	var height := bounds.size.y + 200.0

	var left := Vector2(bounds.position.x + thickness * 0.5, top + height * 0.5)
	var right := Vector2(bounds.position.x + bounds.size.x - thickness * 0.5, top + height * 0.5)
	var wall_size := Vector2(thickness, height)

	# Build now when the physics server is idle; defer when it is mid-flush. A floor
	# can legitimately be constructed from inside a physics callback — travelling
	# through a portal happens in `area_entered`, and TowerController loads the next
	# floor straight from there — and adding a collision shape during query flushing
	# is illegal. The error it raises left the wall without its collision, i.e. a
	# wall that silently does not exist.
	var flushing: bool = Engine.is_in_physics_frame()
	if flushing:
		_add_wall.call_deferred(left, wall_size)
		_add_wall.call_deferred(right, wall_size)
	else:
		_add_wall(left, wall_size)
		_add_wall(right, wall_size)


func _add_wall(center: Vector2, size: Vector2) -> void:
	if _collision == null:
		return
	var body := StaticBody2D.new()
	body.name = "Wall"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	# Position before entering the tree so the shape is never inserted at the
	# origin and then moved, which is what triggered the one-way-collision error.
	body.position = center
	_collision.add_child(body)


## Places loot on the lip of the shaft, which is what makes the hole read as the
## reward marker rather than just a hazard: you can see the loot below through it.
func _build_loot_lip() -> void:
	if _spawn_points == null or floor_data == null:
		return
	var surface: Variant = get_ground_surface_y()
	if surface == null:
		return
	var bounds := floor_data.bounds
	var y := float(surface) - 40.0
	var lip := _shaft_half_width() + 90.0
	var center_x := shaft_center_x()
	for side in [-1.0, 1.0]:
		var marker := Node2D.new()
		marker.name = "LootLip%s" % ("L" if side < 0.0 else "R")
		marker.position = Vector2(center_x + side * lip, y)
		_spawn_points.add_child(marker)

## Call this after instancing if floor_data wasn't set in the inspector.
func set_floor_data(data: FloorData) -> void:
	floor_data = data
	_configure_from_data()
	_update_visual_state()
	
	# Start spawning if floor is active
	if _state == FloorData.FloorState.ACTIVE:
		if is_boss_floor and boss_data != null:
			_setup_boss()
		else:
			var spawner := _enemy_spawner as EnemySpawner
			if spawner != null:
				spawner.start_spawning(_current_floor)

	_spawn_travel_portal()


## Sets the destination floor for this floor's travel portal.
## Spawns the portal if the floor already has data, so callers may set the
## target either before or after set_floor_data().
func set_target_floor(value: int) -> void:
	target_floor = value
	if floor_data != null and _travel_portal == null:
		_spawn_travel_portal()


func _spawn_travel_portal() -> void:
	if target_floor <= 0:
		print("[DEBUG] FloorController: Floor %d has no travel portal (target_floor: %d)" % [_current_floor, target_floor])
		return

	var portal_scene := preload("res://scenes/tower/TravelPortal.tscn")
	if portal_scene == null:
		push_error("FloorController: TravelPortal.tscn not found")
		return

	var bounds := floor_data.bounds if floor_data != null else Rect2(-1000, -1000, 2000, 2000)
	var portal_pos := bounds.position + bounds.size * 0.5 + Vector2(bounds.size.x * 0.4, 0)
	if not bounds.has_point(portal_pos):
		portal_pos.x = clamp(portal_pos.x, bounds.position.x + 100, bounds.position.x + bounds.size.x - 100)
		portal_pos.y = clamp(portal_pos.y, bounds.position.y + 100, bounds.position.y + bounds.size.y - 100)

	_travel_portal = portal_scene.instantiate() as TravelPortal
	_travel_portal.target_floor = target_floor
	add_child(_travel_portal)
	# Position after entering the tree so global_position resolves correctly.
	# The floor sits at the origin, so floor-local and world coords match.
	_travel_portal.global_position = portal_pos
	
	print("[DEBUG] FloorController: Floor %d spawned TravelPortal at position: %s (target_floor: %d, bounds: %s)" % [_current_floor, portal_pos, target_floor, bounds])


func _setup_boss() -> void:
	if boss_data == null:
		return
	
	# Spawn boss at center of floor
	var boss_scene := load("res://scenes/enemies/BossEnemy.tscn")
	if boss_scene == null:
		push_error("FloorController: BossEnemy.tscn not found")
		return
	
	var boss := boss_scene.instantiate() as BossEnemy
	boss.boss_data = boss_data
	boss.global_position = floor_data.bounds.position + floor_data.bounds.size * 0.5
	
	var ai := boss.get_node_or_null("BossAI")
	if ai != null:
		ai.boss_data = boss_data
		ai.phase_changed.connect(_on_boss_phase_changed)
	
	boss.died.connect(_on_boss_died)
	add_child(boss)
	
	SignalHub.boss_spawned.emit(boss, _current_floor)


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


## Returns a random spawn point for loot/players (legacy alias).
func get_random_spawn_point() -> Vector2:
	return get_random_ground_position(false)


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


# ======================================================================== ENEMY SPAWNER SIGNALS

func _on_wave_started(wave: int) -> void:
	SignalHub.wave_started.emit(wave, _current_floor)
	GameLog.info("Floor", "Floor %d: Wave %d started" % [_current_floor, wave])


func _on_wave_completed(wave: int) -> void:
	SignalHub.wave_completed.emit(wave, _current_floor)
	GameLog.info("Floor", "Floor %d: Wave %d completed" % [_current_floor, wave])


func _on_all_waves_completed() -> void:
	SignalHub.all_waves_completed.emit(_current_floor)
	GameLog.info("Floor", "Floor %d: All waves completed" % [_current_floor])


func _on_enemy_spawned(enemy: Node) -> void:
	SignalHub.enemy_spawned_on_floor.emit(enemy, _current_floor)


# ======================================================================== BOSS SIGNALS

func _on_boss_phase_changed(phase: int) -> void:
	SignalHub.boss_phase_changed_on_floor.emit(phase, _current_floor)
	GameLog.info("Floor", "Floor %d: Boss phase %d" % [_current_floor, phase])


func _on_boss_died(killer: Node) -> void:
	SignalHub.boss_died_on_floor.emit(killer, _current_floor)
	GameLog.info("Floor", "Floor %d: Boss defeated by %s" % [_current_floor, killer.name if killer else "unknown"])
	
	# Spawn boss rewards
	_on_boss_rewards(killer)


func _on_boss_rewards(killer: Node) -> void:
	if boss_data == null or killer == null:
		return
	
	var currency := killer.get_node_or_null("CurrencyComponent")
	var inventory := killer.get_node_or_null("InventoryComponent")
	
	if currency != null:
		currency.add_xp(boss_data.reward_xp)
		currency.add_gold(boss_data.reward_gold)
	
	if inventory != null:
		for item_drop in boss_data.reward_items:
			if item_drop.type == "gold":
				continue  # already handled
			elif item_drop.type == "item":
				var item := load("res://resources/items/%s.tres" % item_drop.item_id)
				if item != null:
					inventory.add_item(item, item_drop.count)
