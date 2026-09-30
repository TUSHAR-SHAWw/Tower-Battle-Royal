class_name IdleState
extends State

## Standing still. Transitions to Move/Sprint on input, Dead on death.
## Gravity still applies while idle so the player lands on the ground instead of
## floating when they walk off a ledge.

var _movement: MovementComponent
var _health: HealthComponent
var _input: InputSource


func enter(_message: Dictionary = {}) -> void:
	_movement = host.get_node_or_null("MovementComponent") as MovementComponent
	_health = host.get_node_or_null("HealthComponent") as HealthComponent
	# Deliberately no halt() here.
	#
	# Idle is the state a player starts in and returns to constantly, and entering
	# it used to zero the body's velocity outright. That killed the horizontal
	# speed built up during a jump (so a jump could not carry any distance) and,
	# worse, it wiped a *scripted* velocity on the very next physics frame: the
	# player was on the floor with no input, so Idle called halt() every frame and
	# move_and_slide() never saw a non-zero velocity. Nothing in the game could
	# move the player by writing to velocity.
	#
	# Friction already stops a walking player; halt() is for teleports and death.
	pass


func physics_update(delta: float) -> void:
	# Re-resolved every frame: an InputSource can be replaced at runtime (bots,
	# netplay, tests) and a cached reference would leave the actor unresponsive.
	_input = PlayerStateUtil.resolve_input(host)
	if _health != null and _health.is_dead():
		transition_to(&"dead")
		return
	if _movement == null:
		return
	if _input == null or not _input.is_enabled():
		# Still resolve gravity so the player falls when input is suppressed.
		_movement.apply_motion(delta)
		return

	var intent := _input.poll(host)
	if intent.is_moving():
		if intent.sprint_held:
			transition_to(&"sprint")
		else:
			transition_to(&"move")
		return

	# Braking is skipped when the body already carries more horizontal speed than
	# this actor could produce on its own. That keeps externally-driven motion
	# (a lunge, a knockback, a bot or network input) from being cancelled by the
	# idle state on the very next frame.
	if absf(_movement.velocity().x) <= _resolve_friction_speed_cap():
		_movement.brake(_resolve_friction(), delta)
	PlayerStateUtil.apply_vertical(_movement, intent)
	_movement.apply_motion(delta)


func _resolve_friction() -> float:
	var config := PlayerStateUtil.resolve_config(host)
	return config.friction if config != null else 1200.0


## Above this horizontal speed Idle stops applying friction. Set just over sprint
## speed so normal movement is always braked, but an impulse is not.
func _resolve_friction_speed_cap() -> float:
	var config := PlayerStateUtil.resolve_config(host)
	return (config.sprint_speed * 1.2) if config != null else 400.0


func debug_line() -> String:
	return "Idle"
