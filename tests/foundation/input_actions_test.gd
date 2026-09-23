extends TestCase

## Two jobs:
##   1. prove project.godot's `[input]` section actually parsed (a broken input map
##      is otherwise only noticed when the player cannot move),
##   2. pin the InputIntent contract that every player component reads from.


func test_all_expected_actions_exist() -> void:
	for action: StringName in InputActions.all():
		assert_has(action)


func test_missing_actions_is_empty() -> void:
	var missing := InputActions.missing_actions()
	assert_eq(missing.size(), 0, "project.godot and InputActions are out of sync: %s" % str(missing))


func test_move_actions_have_keyboard_bindings() -> void:
	for action: StringName in [InputActions.MOVE_UP, InputActions.MOVE_DOWN, InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT]:
		var found_key := false
		var events := InputMap.action_get_events(action)
		assert_greater(events.size(), 0.0, "%s must have at least one binding" % action)
		for event: InputEvent in events:
			if event is InputEventKey:
				found_key = true
		assert_true(found_key, "%s needs a keyboard binding" % action)


func test_fire_is_bound_to_a_mouse_button() -> void:
	var found_mouse := false
	for event: InputEvent in InputMap.action_get_events(InputActions.FIRE):
		if event is InputEventMouseButton:
			found_mouse = true
	assert_true(found_mouse, "fire should be reachable with the mouse")


func test_slot_actions_are_six_and_numbered_in_order() -> void:
	assert_eq(InputActions.SLOT_ACTIONS.size(), 6, "the hotbar has six slots (master prompt §30)")
	for index: int in InputActions.SLOT_ACTIONS.size():
		assert_eq(InputActions.SLOT_ACTIONS[index], StringName("slot_%d" % (index + 1)))
		assert_has(InputActions.SLOT_ACTIONS[index])


func test_intent_reset_clears_every_field() -> void:
	var intent := InputIntent.new()
	intent.move_dir = Vector2.LEFT
	intent.sprint_held = true
	intent.aim_dir = Vector2.UP
	intent.aim_position = Vector2(10.0, 20.0)
	intent.has_aim_position = true
	intent.fire_held = true
	intent.fire_pressed = true
	intent.reload_pressed = true
	intent.melee_pressed = true
	intent.interact_pressed = true
	intent.use_pressed = true
	intent.map_pressed = true
	intent.requested_slot = 3

	intent.reset()

	assert_eq(intent.move_dir, Vector2.ZERO)
	assert_false(intent.sprint_held)
	assert_eq(intent.aim_dir, Vector2.RIGHT, "aim falls back to facing right")
	assert_false(intent.has_aim_position)
	assert_false(intent.fire_held)
	assert_false(intent.fire_pressed)
	assert_false(intent.reload_pressed)
	assert_false(intent.melee_pressed)
	assert_false(intent.interact_pressed)
	assert_false(intent.use_pressed)
	assert_false(intent.map_pressed)
	assert_eq(intent.requested_slot, -1, "no slot requested is -1, slot 1 is 0")


func test_intent_copy_from_duplicates_state() -> void:
	var source := InputIntent.new()
	source.move_dir = Vector2(0.5, -0.5)
	source.fire_held = true
	source.requested_slot = 2

	var target := InputIntent.new()
	target.copy_from(source)

	assert_eq(target.move_dir, source.move_dir)
	assert_true(target.fire_held)
	assert_eq(target.requested_slot, 2)


func test_is_moving_ignores_near_zero_drift() -> void:
	var intent := InputIntent.new()
	assert_false(intent.is_moving(), "a reset intent is not moving")
	intent.move_dir = Vector2(0.00001, 0.0)
	assert_false(intent.is_moving(), "analog drift below the threshold must not count as movement")
	intent.move_dir = Vector2(0.5, 0.0)
	assert_true(intent.is_moving())


func test_disabled_source_reports_no_input() -> void:
	var source := InputSource.new()
	add_child(source)  # parented so the suite frees it (no leaked nodes at exit)
	source.set_enabled(false)
	source.intent.move_dir = Vector2.RIGHT
	var polled := source.poll(null)
	assert_false(polled.is_moving(), "a disabled source must report an empty intent")
	assert_eq(polled.requested_slot, -1)
