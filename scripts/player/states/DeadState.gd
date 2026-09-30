class_name DeadState
extends State

## Dead. Stops all movement, disables input, waits for revive/respawn.


var _movement: MovementComponent
var _input: InputSource
var _health: HealthComponent


func enter(_message: Dictionary = {}) -> void:
	_movement = host.get_node_or_null("MovementComponent") as MovementComponent
	# Re-resolved rather than cached: the source may have been replaced since this
	# state last ran (bots, netplay, tests).
	_input = PlayerStateUtil.resolve_input(host)
	_health = host.get_node_or_null("HealthComponent") as HealthComponent

	if _movement != null:
		_movement.halt()
	if _input != null:
		_input.set_enabled(false)

	# Emit global death signal for HUD, match logic, etc.
	SignalHub.player_died.emit(host, _message.get("killer"))


func exit() -> void:
	var source := PlayerStateUtil.resolve_input(host)
	if source != null:
		source.set_enabled(true)


func physics_update(_delta: float) -> void:
	# Dead state does nothing until revived externally.
	pass


func debug_line() -> String:
	return "Dead"