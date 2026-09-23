class_name State
extends Node

## One state of a StateMachine.
##
## States are child *nodes* rather than code-built objects so they appear in the
## editor and in the remote scene tree — when a player gets stuck, the first
## debugging question is "which state is it in, and is that node there?", and this
## design answers both immediately.
##
## `machine` is typed loosely (Node) to avoid a circular class reference between
## State and StateMachine, which GDScript handles poorly.

@export var state_name: StringName = &""

## Set by StateMachine.setup().
var machine: Node = null
## The actor this state acts on (Player, FloorController, ...).
var host: Node = null


## Called when the state becomes active. `message` carries transition payloads.
func enter(_message: Dictionary = {}) -> void:
	pass


## Called when the state is left. Always runs before the next state's enter().
func exit() -> void:
	pass


## Called every idle frame while active.
func update(_delta: float) -> void:
	pass


## Called every physics frame while active — gameplay belongs here, not in update().
func physics_update(_delta: float) -> void:
	pass


## One-line summary shown by the debug overlay.
func debug_line() -> String:
	return String(state_name)


## Convenience for the common `machine.transition_to(&"...")` call.
func transition_to(next_state: StringName, message: Dictionary = {}) -> bool:
	if machine == null:
		push_error("State '%s' has no StateMachine; call StateMachine.setup() first." % state_name)
		return false
	return machine.transition_to(next_state, message)
