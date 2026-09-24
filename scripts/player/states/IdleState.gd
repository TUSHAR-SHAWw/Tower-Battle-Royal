class_name IdleState
extends State

## Standing still. Transitions to Move/Sprint on input, Dead on death.


var _movement: MovementComponent
var _health: HealthComponent
var _input: InputSource


func enter(_message: Dictionary = {}) -> void:
	_movement = host.get_node_or_null("MovementComponent") as MovementComponent
	_health = host.get_node_or_null("HealthComponent") as HealthComponent
	_input = host.get_node_or_null("InputSource") as InputSource
	if _movement != null:
		_movement.halt()


func physics_update(delta: float) -> void:
	if _health != null and _health.is_dead():
		transition_to(&"dead")
		return
	if _input == null or not _input.is_enabled():
		return
	var intent := _input.poll(host)
	if intent.is_moving():
		if intent.sprint_held:
			transition_to(&"sprint")
		else:
			transition_to(&"move")


func debug_line() -> String:
	return "Idle"