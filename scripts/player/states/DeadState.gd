class_name DeadState
extends State

## Dead. Stops all movement, disables input, waits for revive/respawn.


var _movement: MovementComponent
var _input: InputSource
var _health: HealthComponent


func enter(_message: Dictionary = {}) -> void:
	_movement = host.get_node_or_null("MovementComponent") as MovementComponent
	_input = host.get_node_or_null("InputSource") as InputSource
	_health = host.get_node_or_null("HealthComponent") as HealthComponent

	if _movement != null:
		_movement.halt()
	if _input != null:
		_input.set_enabled(false)

	# Emit global death signal for HUD, match logic, etc.
	SignalHub.player_died.emit(host, _message.get("killer"))


func exit() -> void:
	if _input != null:
		_input.set_enabled(true)


func physics_update(_delta: float) -> void:
	# Dead state does nothing until revived externally.
	pass


func debug_line() -> String:
	return "Dead"