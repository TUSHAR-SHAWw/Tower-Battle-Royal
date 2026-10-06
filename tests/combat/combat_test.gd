extends TestCase

var _shooter: Player
var _target: Enemy


func before_suite() -> void:
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	assert_not_null(player_scene)
	if player_scene == null:
		return
	_shooter = player_scene.instantiate() as Player
	assert_not_null(_shooter)
	if _shooter == null:
		return
	get_tree().root.add_child.call_deferred(_shooter)
	await get_tree().physics_frame

	_shooter.input_source.set_enabled(false)
	_shooter.set_physics_process(false)
	_shooter.state_machine.set_physics_process(false)
	_shooter.global_position = Vector2(100.0, 100.0)
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn") as PackedScene
	assert_not_null(enemy_scene)
	if enemy_scene == null:
		return
	_target = enemy_scene.instantiate() as Enemy
	assert_not_null(_target)
	if _target == null:
		return
	_target.name = "DamageableTarget"
	_target.global_position = Vector2(400.0, 100.0)
	get_tree().root.add_child.call_deferred(_target)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_target.ai.set_physics_process(false)


func after_suite() -> void:
	var dead_enemies: Array[Node] = []
	var death_callback := func(enemy: Node, _killer: Node) -> void:
		dead_enemies.append(enemy)
	if _target != null and is_instance_valid(_target):
		SignalHub.enemy_died.connect(death_callback)
		_target.health.kill(_shooter)
		SignalHub.enemy_died.disconnect(death_callback)
		assert_eq(dead_enemies.size(), 1, "one enemy death should publish one global event")
		if not dead_enemies.is_empty():
			assert_eq(dead_enemies[0], _target)
	if _shooter != null and is_instance_valid(_shooter):
		_shooter.queue_free()
	if _target != null and is_instance_valid(_target):
		_target.queue_free()
	await get_tree().physics_frame


func before_each() -> void:
	if _shooter == null or _target == null:
		return
	_shooter.global_position = Vector2(100.0, 100.0)
	_shooter.velocity = Vector2.ZERO
	_target.global_position = Vector2(400.0, 100.0)
	_target.health.current_health = _target.health.max_health
	_target.ai.set_physics_process(false)
	await get_tree().physics_frame


func test_enemy_ai_moves_toward_the_local_player() -> void:
	assert_not_null(_target.enemy_data, "production enemy scene should include its default data resource")
	assert_eq(_target.ai.enemy_data, _target.enemy_data)
	_target.ai.set_physics_process(true)
	_target.ai.force_target(_shooter)
	for _i: int in range(12):
		await get_tree().physics_frame
		if _target.global_position.x < 400.0:
			break

	assert_less(_target.global_position.x, 400.0, "enemy AI should move toward the registered player")


func test_gun_fires_a_pooled_projectile_that_damages_hurtbox() -> void:
	assert_not_null(_shooter.gun.weapon, "player weapon resource must be configured")
	assert_greater(float(_shooter.gun.get_current_mag()), 0.0, "gun must have ammunition")
	if _shooter.gun.weapon == null:
		return
	var ammo_before := _shooter.gun.get_current_mag()
	var health_before: float = _target.health.current_health

	assert_true(_shooter.gun.try_fire(Vector2.RIGHT, _shooter.global_position))
	for _i: int in range(30):
		await get_tree().physics_frame
		if _target.health.current_health < health_before:
			break

	assert_eq(_shooter.gun.get_current_mag(), ammo_before - 1)
	assert_less(_target.health.current_health, health_before, "projectile should damage an enemy hurtbox")


func test_melee_attack_activates_hitbox_and_damages_target() -> void:
	_shooter.velocity = Vector2.ZERO
	assert_true(_shooter.melee.try_attack(Vector2.RIGHT), "melee attack should start")
	_target.global_position = _shooter.global_position + Vector2(40.0, 0.0)
	var health_before: float = _target.health.current_health
	var hitbox := _shooter.get_node("MeleeHitbox") as Area2D
	var target_hurtbox := _target.get_node("Hurtbox") as Area2D
	var target_overlapped: bool = false
	var hit_targets: Array[Node] = []
	var hit_callback := func(target: Node, _position: Vector2, _normal: Vector2) -> void:
		hit_targets.append(target)
	hitbox.hit.connect(hit_callback)

	for _i: int in range(12):
		await get_tree().physics_frame
		if hitbox.monitoring:
			target_overlapped = target_overlapped or hitbox.get_overlapping_areas().has(target_hurtbox)
		if _target.health.current_health < health_before:
			break

	assert_true(target_overlapped, "melee hitbox should overlap the enemy hurtbox during its active frames")
	assert_greater(hit_targets.size(), 0, "melee hitbox should accept the overlapping enemy hurtbox")
	assert_less(_target.health.current_health, health_before, "active melee hitbox should damage a target in range")
