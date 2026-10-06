class_name EnemySpawner
extends Node

## Spawns enemies in waves, scaled by floor.

signal wave_started(wave: int)
signal wave_completed(wave: int)
signal enemy_spawned(enemy: Node)
signal all_waves_completed()

@export var floor_controller: Node = null
@export var enemy_types: Array[EnemyResource] = []
@export var base_wave_count: int = 3
@export var enemies_per_wave: int = 5
@export var wave_interval: float = 10.0
@export var spawn_radius: float = 400.0
@export_range(0.0, 1.0) var loot_drop_chance: float = 0.3

var _current_wave: int = 0
var _enemies_alive: int = 0
var _pending_spawns: int = 0
var _spawn_delays: Array[float] = []
var _wave_timer: float = 0.0
var _spawning: bool = false
var _floor: int = 1
var _spawn_generation: int = 0
var _wave_cleared: bool = false

func _ready() -> void:
	pass


func start_spawning(floor: int) -> void:
	_spawn_generation += 1
	_floor = floor
	_current_wave = 0
	_enemies_alive = 0
	_pending_spawns = 0
	_spawn_delays.clear()
	_wave_cleared = false
	_spawning = true
	_wave_timer = 0.0
	_start_next_wave()


func stop_spawning() -> void:
	_spawning = false
	_spawn_generation += 1
	_pending_spawns = 0
	_spawn_delays.clear()


func _physics_process(delta: float) -> void:
	if not _spawning:
		return

	for i: int in range(_spawn_delays.size() - 1, -1, -1):
		_spawn_delays[i] -= delta
		if _spawn_delays[i] <= 0.0:
			_spawn_delays.remove_at(i)
			call_deferred("_spawn_enemy", _spawn_generation)

	if _current_wave <= 0:
		return

	if _enemies_alive > 0 or _pending_spawns > 0:
		return

	if not _wave_cleared:
		_wave_cleared = true
		wave_completed.emit(_current_wave)
		if _current_wave >= base_wave_count:
			_spawning = false
			print("[DEBUG] EnemySpawner: All waves completed on floor %d" % _floor)
			all_waves_completed.emit()
			return

	_wave_timer += delta
	if _wave_timer >= wave_interval:
		_wave_timer = 0.0
		_start_next_wave()


func _start_next_wave() -> void:
	_current_wave += 1
	_wave_cleared = false
	
	var count := enemies_per_wave + _current_wave - 1
	
	print("[DEBUG] EnemySpawner: Floor %d, Wave %d/%d starting (spawning %d enemies)" % [_floor, _current_wave, base_wave_count, count])
	
	wave_started.emit(_current_wave)
	
	for i in range(count):
		_pending_spawns += 1
		_spawn_delays.append(i * 0.5)


## Spawns one enemy.
##
## `floor_controller` is the FloorController that owns this spawner, so the spawn
## position comes straight from it. The old code asked it for a *child* floor via
## `get_current_floor()`, a method it does not have — the guard failed and every
## enemy in the game spawned at (0, 0).
func _spawn_enemy(generation: int) -> void:
	if generation != _spawn_generation or not _spawning:
		return

	var enemy_type := _pick_enemy_type()
	if enemy_type == null:
		_abort_spawning("cannot spawn wave %d on floor %d without a valid enemy type." % [
			_current_wave, _floor,
		])
		return

	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	if enemy_scene == null:
		_abort_spawning("failed to load res://scenes/enemies/Enemy.tscn.")
		return
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		_abort_spawning("Enemy.tscn root is not an Enemy.")
		return
	var enemy_parent := get_parent()
	if enemy_parent == null:
		_abort_spawning("cannot spawn without a parent floor.")
		enemy.free()
		return

	# Configuring before add_child() lets _ready() see enemy_data and the scaled
	# stats, so the health bar never flashes the unscaled value.
	enemy.enemy_data = enemy_type
	var scaled := enemy_type.get_scaled_stats(_floor)
	var spawn_position := _get_spawn_position()
	enemy.position = (enemy_parent as Node2D).to_local(spawn_position) \
		if enemy_parent is Node2D else spawn_position

	var ai := enemy.get_node_or_null("EnemyAI")
	if ai != null and not ai.died.is_connected(_on_enemy_died):
		ai.died.connect(_on_enemy_died.bind(enemy, scaled))

	_enemies_alive += 1
	_pending_spawns = maxi(_pending_spawns - 1, 0)
	enemy_parent.add_child(enemy)

	# Apply the floor scaling after _ready() so HealthComponent's own clamping
	# does not reset it back to the resource default.
	enemy.health.max_health = scaled.max_health
	enemy.health.current_health = scaled.max_health
	enemy.ai.move_speed = scaled.move_speed

	enemy_spawned.emit(enemy)
	SignalHub.enemy_spawned.emit(enemy)


func _abort_spawning(reason: String) -> void:
	push_error("EnemySpawner: %s" % reason)
	stop_spawning()


## Picks a spawn point on the floor's ground surface, spread across the width so
## a wave arrives from several directions instead of one cluster.
func _get_spawn_position() -> Vector2:
	var floor: Node = floor_controller
	if floor == null:
		return Vector2.ZERO

	if floor.has_method(&"get_random_ground_position"):
		var ground: Variant = floor.call(&"get_random_ground_position")
		if ground is Vector2:
			return ground

	# Fallback for a floor with no tile ground yet: spread along the bounds.
	var bounds := _floor_bounds()
	var local_position := Vector2(
		randf_range(bounds.position.x + 200.0, bounds.position.x + bounds.size.x - 200.0),
		bounds.position.y + bounds.size.y * 0.5
	)
	return (floor as Node2D).to_global(local_position) if floor is Node2D else local_position


func _floor_bounds() -> Rect2:
	var floor: Node = floor_controller
	if floor != null and "floor_data" in floor and floor.floor_data != null:
		return floor.floor_data.bounds
	return FloorData.DEFAULT_BOUNDS


func _pick_enemy_type() -> EnemyResource:
	if enemy_types.is_empty():
		return null
	
	# Weighted random based on floor
	var weights: Array[float] = []
	for et in enemy_types:
		var w := 1.0
		if et.enemy_id == &"grunt":
			w = 1.0 - _floor * 0.05
		elif et.enemy_id == &"sniper":
			w = _floor * 0.1
		weights.append(max(0.1, w))
	
	var total := 0.0
	for w in weights:
		total += w
	
	var r := randf() * total
	var sum := 0.0
	for i in range(enemy_types.size()):
		sum += weights[i]
		if r <= sum:
			return enemy_types[i]
	
	return enemy_types[0]


func _on_enemy_died(killer: Node, dead_enemy: Node2D, scaled_stats: Dictionary) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	
	# Grant rewards to killer
	if killer != null:
		var currency := killer.get_node_or_null("CurrencyComponent")
		if currency != null:
			currency.add_xp(int(scaled_stats.get("xp_reward", 0)))
			currency.add_gold(int(scaled_stats.get("gold_reward", 0)))

	if randf() < loot_drop_chance:
		var item_id: StringName = [&"health_pack", &"adrenaline"].pick_random()
		var item := load("res://resources/items/%s.tres" % item_id) as ItemResource
		if item == null:
			push_error("EnemySpawner: failed to load loot item '%s'." % item_id)
			return
		_spawn_loot_pickup(item, dead_enemy.global_position)


func _spawn_loot_pickup(item: ItemResource, world_position: Vector2) -> void:
	var pickup_scene := preload("res://scenes/loot/ItemPickup.tscn")
	var pickup := pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		push_error("EnemySpawner: ItemPickup.tscn root is not an ItemPickup.")
		return
	pickup.item = item

	var floor_node := get_parent()
	if floor_node == null:
		pickup.free()
		push_error("EnemySpawner: cannot drop loot without an owning floor.")
		return
	if floor_node is Node2D:
		pickup.position = (floor_node as Node2D).to_local(world_position)
	else:
		pickup.position = world_position
	floor_node.add_child.call_deferred(pickup)


func get_enemies_alive() -> int:
	return _enemies_alive


func get_current_wave() -> int:
	return _current_wave