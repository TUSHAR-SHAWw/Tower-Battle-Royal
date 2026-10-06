extends TestCase


class SpawnFloor:
	extends Node2D

	func get_random_ground_position(_away_from_shaft: bool = true) -> Vector2:
		return to_global(Vector2(500.0, 300.0))


var _floor: SpawnFloor
var _spawner: EnemySpawner
var _killer: Node2D
var _currency: CurrencyComponent
var _inventory: InventoryComponent
var _enemy_data: EnemyResource
var _spawned_enemies: Array[Enemy] = []
var _killers: Array[Node] = []
var _started_waves: Array[int] = []
var _completed_waves: Array[int] = []
var _all_waves_completed: bool = false


func before_suite() -> void:
	_enemy_data = load("res://resources/enemies/grunt.tres") as EnemyResource
	assert_not_null(_enemy_data)
	if _enemy_data == null:
		return

	_floor = SpawnFloor.new()
	_floor.name = "SpawnFloor"
	_floor.position = Vector2(0.0, -FloorData.DEFAULT_BOUNDS.size.y)
	_spawner = EnemySpawner.new()
	_spawner.name = "EnemySpawner"
	_spawner.floor_controller = _floor
	_spawner.enemy_types = [_enemy_data]
	_spawner.base_wave_count = 2
	_spawner.enemies_per_wave = 1
	_spawner.wave_interval = 0.05
	_floor.add_child(_spawner)
	add_child(_floor)

	_killer = Node2D.new()
	_killer.name = "Killer"
	_currency = CurrencyComponent.new()
	_currency.name = "CurrencyComponent"
	_inventory = InventoryComponent.new()
	_inventory.name = "InventoryComponent"
	_killer.add_child(_currency)
	_killer.add_child(_inventory)
	add_child(_killer)
	await get_tree().process_frame
	assert_eq(_currency.name, "CurrencyComponent")
	assert_eq(_inventory.name, "InventoryComponent")

	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_spawner.wave_started.connect(_on_wave_started)
	_spawner.wave_completed.connect(_on_wave_completed)
	_spawner.all_waves_completed.connect(_on_all_waves_completed)


func after_suite() -> void:
	if _spawner != null:
		_spawner.stop_spawning()
	if _floor != null and is_instance_valid(_floor):
		_floor.queue_free()
	if _killer != null and is_instance_valid(_killer):
		_killer.queue_free()
	await get_tree().process_frame


func test_waves_stagger_spawns_reward_kills_and_complete() -> void:
	_spawner.start_spawning(2)

	for _i: int in range(10):
		if _spawned_enemies.size() >= 1:
			break
		await get_tree().physics_frame
	assert_eq(_spawned_enemies.size(), 1, "first enemy should spawn immediately")
	assert_eq(_spawned_enemies[0].global_position, Vector2(500.0, -780.0),
		"enemy spawn should preserve world position on an offset floor")
	assert_eq(_started_waves, [1])

	_kill_alive_enemies()
	for _i: int in range(20):
		if _started_waves.size() >= 2:
			break
		await get_tree().physics_frame
	assert_eq(_completed_waves, [1], "clearing a wave should publish its completion")
	assert_eq(_started_waves, [1, 2], "next wave should begin after the configured interval")
	for _i: int in range(10):
		if _spawned_enemies.size() >= 2:
			break
		await get_tree().physics_frame
	assert_eq(_spawned_enemies.size(), 2, "second wave should spawn its first enemy")

	for _i: int in range(10):
		await get_tree().physics_frame
	assert_eq(_spawned_enemies.size(), 2, "subsequent spawns should respect their delay")

	for _i: int in range(40):
		if _spawned_enemies.size() >= 3:
			break
		await get_tree().physics_frame
	assert_eq(_spawned_enemies.size(), 3, "the second wave should grow by one enemy")

	_kill_alive_enemies()
	for _i: int in range(20):
		if _all_waves_completed:
			break
		await get_tree().physics_frame

	assert_true(_all_waves_completed, "clearing the final wave should end spawning")
	assert_eq(_completed_waves, [1, 2])
	assert_eq(_killers.size(), 3, "every enemy death should report its credited killer")
	for killer: Node in _killers:
		assert_eq(killer, _killer, "enemy death should retain the original damage instigator")
	assert_eq(_currency.xp, 120, "scaled enemy XP rewards should be granted per kill")
	assert_eq(_currency.gold, 57, "scaled enemy gold rewards should be granted per kill")


func _kill_alive_enemies() -> void:
	for enemy: Enemy in _spawned_enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			enemy.health.kill(_killer)


func _on_enemy_spawned(enemy: Node) -> void:
	var spawned := enemy as Enemy
	_spawned_enemies.append(spawned)
	spawned.ai.died.connect(_on_enemy_killed)


func _on_enemy_killed(killer: Node) -> void:
	_killers.append(killer)


func _on_wave_started(wave: int) -> void:
	_started_waves.append(wave)


func _on_wave_completed(wave: int) -> void:
	_completed_waves.append(wave)


func _on_all_waves_completed() -> void:
	_all_waves_completed = true
