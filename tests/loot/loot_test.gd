extends TestCase


class SpawnFloor:
	extends Node2D

	func get_random_ground_position(_away_from_shaft: bool = true) -> Vector2:
		return to_global(Vector2(400.0, 300.0))


var _floor: SpawnFloor
var _spawner: EnemySpawner
var _enemy: Enemy
var _killer: Node2D
var _currency: CurrencyComponent
var _player: CharacterBody2D
var _inventory: InventoryComponent


func before_suite() -> void:
	var enemy_data := load("res://resources/enemies/grunt.tres") as EnemyResource
	assert_not_null(enemy_data, "grunt resource must be available")
	if enemy_data == null:
		return

	_floor = SpawnFloor.new()
	_floor.position = Vector2(0.0, -FloorData.DEFAULT_BOUNDS.size.y)
	_spawner = EnemySpawner.new()
	_spawner.floor_controller = _floor
	_spawner.enemy_types = [enemy_data]
	_spawner.base_wave_count = 1
	_spawner.enemies_per_wave = 1
	_spawner.loot_drop_chance = 1.0
	_floor.add_child(_spawner)
	add_child(_floor)

	_killer = Node2D.new()
	_currency = CurrencyComponent.new()
	_currency.name = "CurrencyComponent"
	_killer.add_child(_currency)
	add_child(_killer)
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	await get_tree().process_frame


func after_suite() -> void:
	if _spawner != null:
		_spawner.stop_spawning()
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	if _floor != null and is_instance_valid(_floor):
		_floor.queue_free()
	if _killer != null and is_instance_valid(_killer):
		_killer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_enemy_death_drops_pickup_that_player_can_collect() -> void:
	_spawner.start_spawning(1)
	for _frame: int in range(30):
		if _enemy != null:
			break
		await get_tree().physics_frame
	assert_not_null(_enemy, "spawner should create a production enemy")
	if _enemy == null:
		return

	var death_position := _enemy.global_position
	_enemy.health.kill(_killer)
	for _frame: int in range(5):
		var pickups := _floor.find_children("*", "ItemPickup", true, false)
		if not pickups.is_empty():
			break
		await get_tree().physics_frame

	var pickups := _floor.find_children("*", "ItemPickup", true, false)
	assert_eq(pickups.size(), 1, "enemy death should create one physical pickup")
	if pickups.is_empty():
		return
	var pickup := pickups[0] as ItemPickup
	assert_not_null(pickup.item, "dropped pickup should carry its item resource")
	assert_vector_almost_eq(pickup.global_position, death_position,
		"pickup should spawn at the dead enemy's world position")
	var dropped_item_id := pickup.item.item_id

	_player = CharacterBody2D.new()
	_player.name = "TestPlayer"
	_player.collision_layer = PhysicsLayers.PLAYER
	_player.collision_mask = 0
	_player.add_to_group(&"player")
	var body_shape := CollisionShape2D.new()
	var body_circle := CircleShape2D.new()
	body_circle.radius = 14.0
	body_shape.shape = body_circle
	_player.add_child(body_shape)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = PhysicsLayers.PLAYER_HURTBOX
	hurtbox.collision_mask = 0
	var hurtbox_shape := CollisionShape2D.new()
	var hurtbox_circle := CircleShape2D.new()
	hurtbox_circle.radius = 16.0
	hurtbox_shape.shape = hurtbox_circle
	hurtbox.add_child(hurtbox_shape)
	_player.add_child(hurtbox)
	_inventory = InventoryComponent.new()
	_inventory.name = "InventoryComponent"
	_player.add_child(_inventory)
	_player.global_position = death_position
	add_child(_player)

	for _frame: int in range(10):
		if _inventory.get_item_count(dropped_item_id) > 0:
			break
		await get_tree().physics_frame

	assert_eq(_inventory.get_item_count(dropped_item_id), 1,
		"player body or hurtbox contact should transfer the dropped item to inventory")
	assert_true(pickup.is_queued_for_deletion(),
		"fully collected pickup should remove itself")


func test_stacking_item_emits_one_inventory_update() -> void:
	var item := load("res://resources/items/health_pack.tres") as ItemResource
	assert_not_null(item)
	if item == null:
		return

	var inventory := InventoryComponent.new()
	add_child(inventory)
	await get_tree().process_frame
	var updates: Array[StringName] = []
	inventory.item_added.connect(func(item_id: StringName, _slot: int) -> void:
		updates.append(item_id)
	)
	inventory.add_item(item, 1)
	inventory.add_item(item, 1)

	assert_eq(inventory.get_item_count(item.item_id), 2,
		"stacked pickups should increment the existing stack")
	assert_eq(updates, [item.item_id, item.item_id],
		"each inventory addition should emit exactly one UI update")


func _on_enemy_spawned(enemy: Node) -> void:
	_enemy = enemy as Enemy
