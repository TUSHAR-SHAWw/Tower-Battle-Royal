class_name MoveState
extends State

## Walking horizontally. Transitions to Idle on no input, Sprint on sprint,
## Dead on death. Gravity and jumping are handled by MovementComponent.


var _movement: MovementComponent
var _health: HealthComponent
var _input: InputSource
var _config: PlayerConfig


func enter(_message: Dictionary = {}) -> void:
	_movement = host.get_node_or_null("MovementComponent") as MovementComponent
	_health = host.get_node_or_null("HealthComponent") as HealthComponent
	_config = PlayerStateUtil.resolve_config(host)


func physics_update(delta: float) -> void:
	# Re-resolved every frame: an InputSource can be replaced at runtime (bots,
	# netplay, tests) and a cached reference would leave the actor unresponsive.
	_input = PlayerStateUtil.resolve_input(host)
	if _health != null and _health.is_dead():
		transition_to(&"dead")
		return
	if _input == null or not _input.is_enabled() or _movement == null:
		transition_to(&"idle")
		return
	if _config == null:
		_config = PlayerStateUtil.resolve_config(host)
		if _config == null:
			transition_to(&"idle")
			return

	var intent := _input.poll(host)
	# Keep air control: a jump in progress must not drop us back to Idle, or the
	# player would freeze mid-jump every time they left the ground.
	if not intent.is_moving() and _movement.is_on_floor():
		transition_to(&"idle")
		return
	if intent.is_moving() and intent.sprint_held:
		transition_to(&"sprint")
		return

	_movement.set_facing(intent.move_dir)
	_movement.accelerate_toward(intent.move_dir, _config.walk_speed, _config.acceleration, delta)
	PlayerStateUtil.apply_vertical(_movement, intent)
	_movement.apply_motion(delta)


func debug_line() -> String:
	return "Move"
