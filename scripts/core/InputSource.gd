class_name InputSource
extends Node

## Base class for anything that can drive a player.
##
## Implementations today: InputDriver (keyboard/mouse). Planned: BotInputDriver
## (M7 test bots) and NetworkInputDriver (M20). Owners call `poll()` once per
## frame and hand the returned intent to the player's components — components
## never touch devices, which is what makes bots and netplay possible later.
##
## The intent object is reused every frame (see InputIntent) so polling allocates
## nothing; treat the result as valid only for the frame it was polled in.

var intent: InputIntent = InputIntent.new()

var _enabled: bool = true


func _init() -> void:
	set_process(false)


## When disabled the source reports "no input at all" (used while the cheat
## console has focus, during cutscenes, when dead, ...).
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


## Returns this frame's intent (never null). `host` is the node the input is read
## relative to — for mouse aiming that is the player node itself.
func poll(host: Node2D = null) -> InputIntent:
	intent.reset()
	if not _enabled:
		return intent
	_read_input(intent, host)
	return intent


## Override in subclasses. Must only write into `intent`.
func _read_input(_intent: InputIntent, _host: Node2D) -> void:
	pass


## True for input that came from a human at this machine.
func is_local() -> bool:
	return true
