extends TestCase

## M1 player integration tests.
##
## Drives the real Player through its own input path: an InputSource produces an
## InputIntent, and the state machine consumes it across real physics frames.
##
## Why it drives input rather than MovementComponent directly: the state machine
## owns movement in this design (ARCHITECTURE.md §6 — "components never call
## Input"). An earlier version of this suite called
## `movement.accelerate_toward()` by hand, and the Idle state then braked and
## re-applied motion on the same frame, so the test was measuring its own calls
## being overwritten. It reported "2 assertions, 0 failures" while testing
## nothing: `before_suite()` was not awaited, so every test ran before the fixture
## existed and died on a null.
##
## Every component lookup goes through a null-safe helper that records an
## assertion failure, so a broken fixture can never look like a passing suite.

var _player: Node
var _match: Node2D
var _movement: MovementComponent
var _health: HealthComponent
var _state_machine: StateMachine
var _camera_component: CameraComponent
var _config: PlayerConfig
## Swapped in for the scene's InputDriver so the tests drive intent, not devices.
var _input_source: ScriptedInputSource

## Where the player was standing when the suite started, restored before each test.
var _spawn_position: Vector2 = Vector2.ZERO
## Fastest speed observed during the most recent `_drive()` call.
var _peak_speed: float = 0.0


func before_suite() -> void:
	var match_scene: PackedScene = load("res://scenes/main/Match.tscn") as PackedScene
	assert_not_null(match_scene)
	_match = match_scene.instantiate()
	assert_not_null(_match)
	# Deferred: adding a scene from inside another node's _ready() fails with
	# "Parent node is busy setting up children", and the failure is silent — the
	# Player never runs, every component is null, and the suite still passed.
	get_tree().root.add_child.call_deferred(_match)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_player = _match.get_node_or_null("PlayerInstance")
	assert_not_null(_player, "PlayerInstance must exist under Match")
	if _player == null:
		return

	_movement = _null_safe_node("MovementComponent") as MovementComponent
	_health = _null_safe_node("HealthComponent") as HealthComponent
	_state_machine = _null_safe_node("StateMachine") as StateMachine
	_camera_component = _null_safe_node("CameraComponent") as CameraComponent

	assert_not_null(_movement, "MovementComponent")
	assert_not_null(_health, "HealthComponent")
	assert_not_null(_state_machine, "StateMachine")

	# Replace the device-driven InputDriver with a scripted one. The player reads
	# its intent from the attached InputSource, so this makes the whole input path
	# deterministic without touching gameplay code or synthesising InputEvents.
	_install_scripted_input()
	assert_not_null(_input_source, "ScriptedInputSource")

	# The config is an @export Resource on Player.gd, NOT a child node. Reading it
	# from a node called "PlayerConfig" (which does not exist) returned null.
	_config = _player.get(&"config") as PlayerConfig
	if _config == null:
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
		return

	_spawn_position = _player.global_position


func after_suite() -> void:
	if _match != null and is_instance_valid(_match):
		_match.queue_free()
		await get_tree().physics_frame


## Restores a live, idle, standing player before every test.
##
## Without this each test inherited the previous one's damage, death and position:
## the sprint test ran against a corpse killed by the damage test, and reported
## "expected sprint, got dead".
func before_each() -> void:
	if _player == null or _health == null:
		return
	_health.revive()
	_reset_vitals()
	_player.global_position = _spawn_position
	_player.velocity = Vector2.ZERO
	if _input_source != null:
		_input_source.set_enabled(true)
	_reset_intent()
	# End any in-progress state explicitly, then settle: one frame for the
	# transition to take, and further frames for the body to land on the slab.
	# The player spawns slightly airborne, and measuring from a falling body makes
	# the movement assertions meaningless — a test that reads its start position
	# mid-fall can report zero movement while the player is actually walking.
	if _state_machine != null and _state_machine.has_state(&"idle"):
		_state_machine.transition_to(&"idle")
	await _settle()


func after_each() -> void:
	# A match runs hunger and rage, and Player multiplies movement speed by both.
	# Left alone, a starving player walks at roughly half speed and every speed
	# assertion silently becomes a test of the metabolism system instead.
	_reset_vitals()


## Puts hunger and rage back to neutral so speed assertions measure movement only.
func _reset_vitals() -> void:
	if _player == null:
		return
	var hunger := _player.get_node_or_null("HungerComponent")
	if hunger != null:
		hunger.set(&"current_hunger", hunger.get(&"max_hunger"))
	var rage := _player.get_node_or_null("RageComponent")
	if rage != null:
		rage.set(&"current_rage", 0.0)


## Waits until the player is standing on the floor with no residual motion.
##
## Bounded, so a player that never lands fails the test rather than hanging it.
func _settle(max_frames: int = 90) -> void:
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if _player == null or not is_instance_valid(_player):
			return
		if _player.is_on_floor() and _movement != null and _movement.speed() < 5.0:
			break
	_reset_intent()
	await get_tree().physics_frame


## Clears the scripted intent so a test only sees what it asked for.
##
## The intent lives on the InputSource (that is the object `poll()` reads from), so
## resetting it here is what actually clears the frame's input — writing to a
## separate copy would leave the previous frame's direction held down.
func _reset_intent() -> void:
	if _input_source == null:
		return
	var intent := _input_source.scripted
	intent.reset()
	intent.move_dir = Vector2.ZERO
	intent.aim_dir = Vector2.RIGHT


## Swaps the player's InputSource for a scripted one.
##
## The replacement MUST keep the node name "InputSource": the states resolve their
## input with `get_node_or_null("InputSource")`, so a differently-named node leaves
## them polling the old driver.
##
## The scene's original driver is RENAMED and disabled rather than freed. Freeing
## it left the name free for the rest of the frame, so two nodes answered to
## "InputSource" and the states could bind the dead one — which reads as the player
## ignoring input entirely, with nothing in the log to explain it.
func _install_scripted_input() -> void:
	if _player == null:
		return
	var old := _player.get_node_or_null("InputSource")
	if old != null:
		old.name = "InputSourceDisabled"
		if old.has_method(&"set_enabled"):
			old.call(&"set_enabled", false)
		old.set_process(false)

	var driver := ScriptedInputSource.new()
	driver.name = "InputSource"
	_player.add_child(driver)
	_player.set(&"input_source", driver)
	_input_source = driver


## Holds `direction` (optionally sprinting) for `frames` physics frames.
##
## The intent is written into the source's own intent object and one frame is
## waited, so the state machine, the movement component and the camera all run
## exactly as they do in play.
##
## The fastest speed reached during the run is recorded in `_peak_speed`, because
## reading velocity after the final frame is unreliable: the state machine has
## already re-run for the next frame with the intent cleared, so the body can
## legitimately read zero immediately after a frame of full-speed movement.
func _drive(direction: Vector2, frames: int, sprint: bool = false) -> void:
	_peak_speed = 0.0
	for _i: int in range(frames):
		var intent := _input_source.scripted
		intent.reset()
		intent.move_dir = direction
		intent.sprint_held = sprint
		intent.aim_dir = direction if not direction.is_zero_approx() else Vector2.RIGHT
		await get_tree().physics_frame
		if _movement != null:
			_peak_speed = maxf(_peak_speed, _movement.speed())


## Reads a property without touching the base object when it is null.
func _null_safe_node(node_name: String) -> Node:
	if _player == null:
		return null
	return _player.get_node_or_null(NodePath(node_name))


# ------------------------------------------------------------------ movement

func test_player_spawns_alive_and_idle() -> void:
	assert_false(_health.is_dead())
	assert_eq(_health.current_health, _config.max_health)
	assert_eq(_state_machine.current_state_name(), &"idle")


func test_player_stands_on_the_floor() -> void:
	# Standing matters: the spawn used to place the player at a random x that could
	# be outside the walls, or over the central shaft, and they fell out of the map.
	assert_true(_player.is_on_floor(), "player should spawn resting on the floor slab")
	assert_true(_movement.is_on_floor(), "MovementComponent should agree the player is grounded")


func test_player_walks_when_input_is_held() -> void:
	var start_x: float = _player.global_position.x
	_drive(Vector2.RIGHT, 30)

	# Speed is read from the peak observed DURING the run, not after it: the state
	# machine re-runs for the next frame with the intent already cleared, so the
	# body can read zero immediately after a frame of full-speed movement.
	assert_greater(_peak_speed, 50.0, "player should reach walking speed while input is held")
	assert_greater(_player.global_position.x - start_x, 60.0, "30 frames of walking should cover ground")
	assert_eq(_state_machine.current_state_name(), &"move")


func test_player_stops_when_input_is_released() -> void:
	_drive(Vector2.RIGHT, 30)
	assert_eq(_state_machine.current_state_name(), &"move")

	_drive(Vector2.ZERO, 40)
	await get_tree().physics_frame

	assert_eq(_state_machine.current_state_name(), &"idle")
	assert_less(_movement.speed(), 5.0, "friction should bring the player to a stop")


func test_player_sprints_faster_than_walking() -> void:
	_drive(Vector2.RIGHT, 30)
	var walk_speed: float = _peak_speed
	assert_eq(_state_machine.current_state_name(), &"move")

	_drive(Vector2.RIGHT, 30, true)

	assert_eq(_state_machine.current_state_name(), &"sprint")
	assert_greater(_peak_speed, walk_speed, "sprint must be faster than the walk it replaced")


func test_player_is_clamped_by_the_floor_walls() -> void:
	# Floors are 6400 px wide but the view shows ~1700, so without side walls the
	# player walks off the floor data and falls forever.
	#
	# 220 frames at sprint speed is enough to cross from the middle to the wall and
	# press against it; 900 frames only proved the player eventually left the floor.
	_drive(Vector2.RIGHT, 220, true)
	await get_tree().physics_frame

	var bounds: Rect2 = FloorData.DEFAULT_BOUNDS
	assert_less(_player.global_position.x, bounds.position.x + bounds.size.x + 200.0,
		"player must be stopped by the right-hand wall")
	assert_true(_player.is_on_floor(), "player must still be standing after running into the wall")


# --------------------------------------------------------------------- combat

func test_player_takes_damage() -> void:
	var before: float = _health.current_health
	var info := DamageInfo.create(30.0, DamageTypes.BULLET, _player, _player)
	var applied: float = _player.call("take_damage", info)

	assert_eq(applied, 30.0)
	assert_eq(_health.current_health, before - 30.0)
	assert_false(_health.is_dead())


func test_lethal_damage_kills_and_enters_dead_state() -> void:
	var info := DamageInfo.create(1000.0, DamageTypes.BULLET, _player, _player)
	_player.call("take_damage", info)
	await get_tree().physics_frame

	assert_true(_health.is_dead())
	assert_eq(_state_machine.current_state_name(), &"dead")


func test_dead_player_does_not_move_or_accept_input() -> void:
	_health.kill(_player)
	await get_tree().physics_frame
	assert_eq(_state_machine.current_state_name(), &"dead")

	var start_x: float = _player.global_position.x
	_drive(Vector2.RIGHT, 30)
	await get_tree().physics_frame

	assert_almost_eq(_player.global_position.x, start_x, "a dead player must not walk", 1.0)
	assert_eq(_state_machine.current_state_name(), &"dead")


func test_player_revives_at_full_health() -> void:
	_health.kill(_player)
	await get_tree().physics_frame
	assert_true(_health.is_dead())

	_player.call("revive")
	await get_tree().physics_frame

	assert_false(_health.is_dead())
	assert_eq(_health.current_health, _config.max_health)
	assert_eq(_state_machine.current_state_name(), &"idle")


# --------------------------------------------------------------------- camera

func test_camera_is_current_and_shows_the_configured_view() -> void:
	assert_not_null(_camera_component, "CameraComponent")
	var cam := _camera_component.camera
	assert_not_null(cam, "Camera2D")
	if cam == null:
		return
	# `current` does not exist in Godot 4 — it is `enabled`, and reading the wrong
	# one threw on every physics frame.
	assert_true(cam.enabled, "camera must be enabled/current")

	var expected := _camera_component.visible_world_size()
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	assert_almost_eq(expected.x, float(width) * _config.camera_zoom, "view width", 1.0)


func test_camera_follows_the_player() -> void:
	var cam := _camera_component.camera
	if cam == null:
		return
	var before: Vector2 = cam.global_position
	_drive(Vector2.RIGHT, 90)
	await get_tree().physics_frame

	assert_greater((cam.global_position - before).length(), 1.0, "camera follows the player (rolling framing, 1.5x zoom)")


func test_jumping_does_not_move_the_camera() -> void:
	# A routine jump goes up and comes back to the same ground, so the frame must
	# hold still: the vertical dead zone has to exceed the jump height.
	var cam := _camera_component.camera
	if cam == null:
		return
	_drive(Vector2.ZERO, 10)
	await get_tree().physics_frame
	var ground_y: float = cam.global_position.y

	var intent := _input_source.scripted
	intent.reset()
	intent.jump_pressed = true
	intent.jump_held = true
	await get_tree().physics_frame
	for _i: int in range(30):
		intent.reset()
		intent.jump_held = true
		await get_tree().physics_frame

	assert_less(absf(cam.global_position.y - ground_y), 200.0,
		"a jump must not drag the frame away from the ground line")
