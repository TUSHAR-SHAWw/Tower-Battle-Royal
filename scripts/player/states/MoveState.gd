class_name MoveState
extends State

## Walking. Transitions to Idle on no input, Sprint on sprint, Dead on death.


var _movement: MovementComponent
var _health: HealthComponent
var _input: InputSource
var _config: PlayerConfig


func enter(_message: Dictionary = {}) -> void:
	_movement = host.get_node_or_null("MovementComponent") as MovementComponent
	_health = host.get_node_or_null("HealthComponent") as HealthComponent
	_input = host.get_node_or_null("InputSource") as InputSource
	var config_node := host.get_node_or_null("PlayerConfig")
	_config = config_node.resource as PlayerConfig if config_node != null else null


func physics_update(delta: float) -> void:
	if _health != null and _health.is_dead():
		transition_to(&"dead")
		return
	if _input == null or not _input.is_enabled() or _movement == null or _config == null:
		transition_to(&"idle")
		return

	var intent := _input.poll(host)
	if not intent.is_moving():
		transition_to(&"idle")
		return
	if intent.sprint_held:
		transition_to(&"sprint")
		return

	_movement.set_facing(intent.move_dir)
	_movement.accelerate_toward(intent.move_dir, _config.walk_speed, _config.acceleration, delta)
	_movement.commit()


func debug_line() -> String:
	return "Move"