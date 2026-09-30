class_name SprintState
extends State

## Sprinting horizontally. Transitions to Move when sprint released, Idle on no
## input, Dead on death. Gravity and jumping are handled by MovementComponent.


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
	if not intent.is_moving():
		transition_to(&"idle")
		return
	if not intent.sprint_held:
		transition_to(&"move")
		return

	_movement.set_facing(intent.move_dir)
	_movement.accelerate_toward(intent.move_dir, _config.sprint_speed, _config.acceleration, delta)
	PlayerStateUtil.apply_vertical(_movement, intent)
	_movement.apply_motion(delta)


func debug_line() -> String:
	return "Sprint"
