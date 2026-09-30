extends TestCase

## M1 player integration tests.
##
## Drives a real Player scene with synthetic InputIntents across physics frames
## to verify movement, state transitions, health, death and revive.

var _player: Node
var _match: Node2D
var _movement: MovementComponent
var _health: HealthComponent
var _state_machine: StateMachine
var _camera_component: CameraComponent
var _config: PlayerConfig
var _input_source: InputSource


func before_suite() -> void:
	var match_scene: PackedScene = load("res://scenes/main/Match.tscn") as PackedScene
	assert_not_null(match_scene)
	_match = match_scene.instantiate()
	assert_not_null(_match)
	get_tree().root.add_child(_match)
	await get_tree().physics_frame

	# PlayerInstance IS the Player (CharacterBody2D) because it uses
	# `instance = ExtResource("res://scenes/player/Player.tscn")` in the scene.
	_player = _match.get_node("PlayerInstance")
	assert_not_null(_player)
	assert_true(_player is CharacterBody2D, "PlayerInstance should be the Player CharacterBody2D")

	# Components are read by node name because before_suite() may inspect the tree
	# while the Player is still coming up. Every failure below is turned into a
	# recorded assertion failure instead of a SCRIPT ERROR, so a broken fixture can
	# never again look like a passing suite.
	_movement = _null_safe_node("MovementComponent") as MovementComponent
	_health = _null_safe_node("HealthComponent") as HealthComponent
	_state_machine = _null_safe_node("StateMachine") as StateMachine
	_camera_component = _null_safe_node("CameraComponent") as CameraComponent
	_input_source = _null_safe_node("InputSource") as InputSource

	assert_not_null(_movement, "MovementComponent")
	assert_not_null(_health, "HealthComponent")
	assert_not_null(_state_machine, "StateMachine")
	assert_not_null(_input_source, "InputSource")

	# The config is an @export Resource on Player.gd, NOT a child node. Reading it
	# from a node called "PlayerConfig" (which does not exist) returned null, and
	# every test that needed it died with "Nonexistent function ... in base 'Nil'"
	# while the suite still reported PASS. PlayerStateUtil documents the same bug.
	_config = _null_safe_get(&"config") as PlayerConfig
	if _config == null:
		# Fall back to the same resource Player.gd loads when the export is unset.
		_config = load("res://resources/player/player_default.tres") as PlayerConfig
	assert_not_null(_config, "PlayerConfig must resolve from Player.config")

	var missing: Array[String] = []
	if _movement == null:
		missing.append("MovementComponent")
	if _health == null:
		missing.append("HealthComponent")
	if _state_machine == null:
		missing.append("StateMachine")
	if _input_source == null:
		missing.append("InputSource")
	if _config == null:
		missing.append("PlayerConfig")
	if not missing.is_empty():
		fail("player_test cannot run — missing %s" % ", ".join(PackedStringArray(missing)))

	await get_tree().physics_frame


## Reads a property without touching the base object when it is null.
func _null_safe_get(property: StringName) -> Variant:
	if _player == null:
		return null
	return _player.get(property)


## Reads a child node without touching the base object when it is null.
func _null_safe_node(node_name: String) -> Node:
	if _player == null:
		return null
	return _player.get_node_or_null(NodePath(node_name))


func after_suite() -> void:
	if _match != null:
		_match.queue_free()
		await get_tree().physics_frame


func test_player_spawns_alive() -> void:
	assert_false(_health.is_dead())
	assert_eq(_health.current_health, 100.0)
	assert_eq(_state_machine.current_state_name(), &"idle")


func test_player_moves_when_input_held() -> void:
	_input_source.set_enabled(true)

	# Hold right for 20 physics frames.
	for _i: int in range(20):
		var intent := InputIntent.new()
		intent.move_dir = Vector2.RIGHT
		intent.sprint_held = false
		_movement.set_facing(intent.move_dir)
		_movement.accelerate_toward(intent.move_dir, _config.walk_speed, _config.acceleration, 1.0/60.0)
		_movement.commit()
		await get_tree().physics_frame

	assert_true(_movement.is_moving())
	assert_greater(_player.global_position.x, 0.0)
	assert_eq(_state_machine.current_state_name(), &"move")

	# Stop input - should transition back to Idle.
	_movement.brake(_config.friction, 1.0/60.0)
	_movement.commit()
	await get_tree().physics_frame
	assert_eq(_state_machine.current_state_name(), &"idle")


func test_player_sprints_when_sprint_held() -> void:
	_input_source.set_enabled(true)

	# Walk first
	for _i: int in range(5):
		var intent := InputIntent.new()
		intent.move_dir = Vector2.RIGHT
		intent.sprint_held = false
		_movement.set_facing(intent.move_dir)
		_movement.accelerate_toward(intent.move_dir, _config.walk_speed, _config.acceleration, 1.0/60.0)
		_movement.commit()
		await get_tree().physics_frame
	assert_eq(_state_machine.current_state_name(), &"move")

	# Now sprint
	for _i: int in range(10):
		var intent := InputIntent.new()
		intent.move_dir = Vector2.RIGHT
		intent.sprint_held = true
		_movement.set_facing(intent.move_dir)
		_movement.accelerate_toward(intent.move_dir, _config.sprint_speed, _config.acceleration, 1.0/60.0)
		_movement.commit()
		await get_tree().physics_frame

	assert_eq(_state_machine.current_state_name(), &"sprint")
	assert_greater(_movement.speed(), _config.walk_speed)


func test_player_takes_damage_and_dies() -> void:
	var initial_health: float = _health.current_health
	var info := DamageInfo.create(30.0, DamageTypes.BULLET, _player, _player)
	var applied: float = _player.call("take_damage", info)
	assert_eq(applied, 30.0)
	assert_eq(_health.current_health, initial_health - 30.0)
	assert_false(_health.is_dead())

	# Kill the player
	info = DamageInfo.create(1000.0, DamageTypes.BULLET, _player, _player)
	applied = _player.call("take_damage", info)
	assert_greater(applied, 0.0)
	assert_true(_health.is_dead())
	assert_eq(_state_machine.current_state_name(), &"dead")
	assert_eq(_movement.velocity(), Vector2.ZERO)


func test_player_revives() -> void:
	# Ensure dead first
	_health.kill(_player)
	await get_tree().physics_frame
	assert_true(_health.is_dead())
	assert_eq(_state_machine.current_state_name(), &"dead")

	# Revive
	_player.call("revive")
	await get_tree().physics_frame

	assert_false(_health.is_dead())
	assert_eq(_health.current_health, 100.0)
	assert_eq(_state_machine.current_state_name(), &"idle")
	assert_true(_input_source.is_enabled())


func test_camera_follows_player() -> void:
	if _camera_component == null or _camera_component.camera == null:
		return
	var cam := _camera_component.camera
	var start_pos: Vector2 = cam.global_position

	# Move player
	_player.global_position = Vector2(500, 300)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Camera should have moved toward player (with smoothing it won't be exact)
	var diff: float = (cam.global_position - start_pos).length()
	assert_greater(diff, 10.0, "camera should follow player")