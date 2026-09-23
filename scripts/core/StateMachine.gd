class_name StateMachine
extends Node

## Reusable, data-free state machine.
##
## Used by three very different systems so the project has exactly one place to
## look when a state transition misbehaves:
##   * Player        (M1) — Idle/Move/Sprint/Dead, later combat states
##   * FloorController (M2/M8) — ACTIVE/WARNING/COLLAPSING/DELETED
##   * FloorTravelComponent (M9) — IDLE/SELECTING/TRAVELLING/ARRIVING
##
## Usage:
##     state_machine.setup(self)   # after the owner's components are ready
##     state_machine.start()
##
## States are child nodes implementing State; their `state_name` must be unique.

signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state_name: StringName = &""
## If true the machine logs every transition (noisy — debug builds only).
@export var log_transitions: bool = true

var host: Node = null
var current_state: State = null

var _states: Dictionary[StringName, State] = {}
var _is_transitioning: bool = false


func setup(new_host: Node) -> void:
	host = new_host
	_states.clear()
	current_state = null
	for child: Node in get_children():
		if child is not State:
			continue
		var state: State = child
		if state.state_name == &"":
			push_error("StateMachine: node '%s' has no state_name; it will be ignored." % child.name)
			continue
		if _states.has(state.state_name):
			push_error("StateMachine: duplicate state_name '%s'; the later node wins." % state.state_name)
		_states[state.state_name] = state
		state.machine = self
		state.host = host


## Enters the initial state. Call after setup(), once the host is fully ready.
func start() -> void:
	if initial_state_name == &"" or not _states.has(initial_state_name):
		push_error("StateMachine: initial_state_name '%s' is not one of %s." % [initial_state_name, state_names()])
		return
	_change_to(_states[initial_state_name], {})


## Requests a transition. Returns false when the request was ignored (unknown
## state, re-entrant call from inside a transition, or already there).
func transition_to(next_state_name: StringName, message: Dictionary = {}) -> bool:
	if not _states.has(next_state_name):
		push_warning("StateMachine: unknown state '%s' requested by '%s'." % [next_state_name, current_state_name()])
		return false
	if _is_transitioning:
		push_warning("StateMachine: transition to '%s' ignored during a transition." % next_state_name)
		return false
	if current_state == null:
		# Transitioning before start() means a caller forgot to initialise the machine.
		push_warning("StateMachine: transition to '%s' ignored before start()." % next_state_name)
		return false
	if current_state.state_name == next_state_name:
		return false
	_change_to(_states[next_state_name], message)
	return true


## Returns the state with this name, or null.
func get_state(state_name: StringName) -> State:
	return _states.get(state_name) as State


func current_state_name() -> StringName:
	return current_state.state_name if current_state != null else &""


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func state_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: Variant in _states.keys():
		names.append(StringName(key))
	# StringName's native ordering is not alphabetical (it is not a string compare),
	# so the comparator converts to String — the debug overlay must be readable.
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return names


func is_started() -> bool:
	return current_state != null


## One-line summary for the debug overlay: "Move (2 states)".
func debug_line() -> String:
	return "%s [%s]" % [current_state_name(), ", ".join(PackedStringArray(state_names()))]


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _change_to(next_state: State, message: Dictionary) -> void:
	_is_transitioning = true
	var previous_name := current_state_name()
	if current_state != null:
		current_state.exit()
	current_state = next_state
	current_state.enter(message)
	_is_transitioning = false

	var new_name := current_state_name()
	if new_name == previous_name:
		return
	if log_transitions:
		GameLog.info("StateMachine", "%s -> %s" % [previous_name if previous_name != &"" else "<none>", new_name])
	state_changed.emit(previous_name, new_name)
