class_name InputDriver
extends InputSource

## Keyboard + mouse (and gamepad) input source.
##
## Aiming is twin-stick: the right stick wins when it is pushed, otherwise the
## mouse cursor position decides the aim direction. That single rule covers
## desktop, gamepad and — later — a right-hand touch stick without changing a
## single gameplay component.

## Below this stick magnitude the right stick is considered untouched and the
## mouse takes over (prevents drift on worn controllers).
const AIM_STICK_THRESHOLD := 0.25


func _read_input(intent: InputIntent, host: Node2D) -> void:
	# Typing in the cheat console must not also drive the player.
	if DevTools.is_console_open():
		return

	intent.move_dir = Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP, InputActions.MOVE_DOWN
	)
	intent.sprint_held = Input.is_action_pressed(InputActions.SPRINT)

	intent.fire_held = Input.is_action_pressed(InputActions.FIRE)
	intent.fire_pressed = Input.is_action_just_pressed(InputActions.FIRE)
	intent.reload_pressed = Input.is_action_just_pressed(InputActions.RELOAD)
	intent.melee_pressed = Input.is_action_just_pressed(InputActions.MELEE_ATTACK)
	intent.interact_pressed = Input.is_action_just_pressed(InputActions.INTERACT)
	intent.use_pressed = Input.is_action_just_pressed(InputActions.USE_SELECTED)
	intent.map_pressed = Input.is_action_just_pressed(InputActions.TOGGLE_MAP)

	_read_aim(intent, host)
	_read_slot(intent)


func _read_aim(intent: InputIntent, host: Node2D) -> void:
	var stick := Input.get_vector(
		InputActions.AIM_LEFT, InputActions.AIM_RIGHT,
		InputActions.AIM_UP, InputActions.AIM_DOWN
	)
	if stick.length() >= AIM_STICK_THRESHOLD:
		intent.aim_dir = stick.normalized()
		intent.has_aim_position = false
		return

	if host == null:
		return
	var aim_point := host.get_global_mouse_position()
	intent.aim_position = aim_point
	intent.has_aim_position = true
	var offset := aim_point - host.global_position
	# Directly on top of the player: keep the previous facing instead of jittering.
	if offset.length_squared() > 0.0001:
		intent.aim_dir = offset.normalized()


func _read_slot(intent: InputIntent) -> void:
	for index: int in InputActions.SLOT_ACTIONS.size():
		if Input.is_action_just_pressed(InputActions.SLOT_ACTIONS[index]):
			intent.requested_slot = index
			return
