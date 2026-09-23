extends TestCase

## The same StateMachine drives players (M1), floor deletion (M8) and floor travel
## (M9), so its contract is pinned here before anything depends on it.
##
## Transitioning to an unknown/nameless state, before start(), or inside another
## transition intentionally emits push_warning()/push_error() log lines. Those are
## expected behaviour — the machine must refuse loudly instead of corrupting state.

class CountingState extends State:
	var enter_messages: Array = []
	var update_calls: int = 0
	var physics_calls: int = 0
	var trace: Array[String] = []

	func enter(message: Dictionary = {}) -> void:
		enter_messages.append(message)
		trace.append("enter:%s" % state_name)

	func exit() -> void:
		trace.append("exit:%s" % state_name)

	func update(_delta: float) -> void:
		update_calls += 1

	func physics_update(_delta: float) -> void:
		physics_calls += 1


class ReentrantState extends State:
	## True once the state proved that a nested transition is refused.
	var nested_transition_refused: bool = false

	func enter(_message: Dictionary = {}) -> void:
		if machine == null:
			return
		var accepted: bool = machine.transition_to(&"move")
		nested_transition_refused = not accepted


var _host: Node
var _machine: StateMachine


func before_each() -> void:
	_host = Node.new()
	_host.name = "Host"
	add_child(_host)
	_machine = null


func after_each() -> void:
	if _machine != null:
		_machine.queue_free()
		_machine = null
	_host.queue_free()


func test_setup_registers_every_state_and_the_host() -> void:
	var machine := _build_machine([&"idle", &"move", &"dead"], &"idle")
	assert_true(machine.has_state(&"move"))
	assert_true(machine.has_state(&"dead"))
	assert_eq(machine.state_names(), [&"dead", &"idle", &"move"], "state_names is sorted for the debug overlay")
	assert_eq(machine.host, _host, "every state gets the host reference")
	assert_false(machine.is_started(), "setup() alone must not enter a state")
	assert_eq(machine.current_state_name(), &"", "no current state before start()")


func test_start_enters_the_initial_state() -> void:
	var machine := _build_machine([&"idle", &"move"], &"idle")
	machine.start()
	assert_true(machine.is_started())
	assert_eq(machine.current_state_name(), &"idle")
	assert_eq((machine.get_state(&"idle") as CountingState).trace, ["enter:idle"])


func test_states_receive_the_machine_and_host_references() -> void:
	var machine := _build_machine([&"idle"], &"idle")
	var state := machine.get_state(&"idle") as CountingState
	assert_eq(state.machine, machine)
	assert_eq(state.host, _host)


func test_transition_reports_previous_and_new_state() -> void:
	var machine := _build_machine([&"idle", &"move"], &"idle")
	machine.start()
	var transitions: Array = []
	var handler := func(from_state: StringName, to_state: StringName) -> void: transitions.append([from_state, to_state])
	machine.state_changed.connect(handler)
	assert_true(machine.transition_to(&"move"))
	machine.state_changed.disconnect(handler)

	assert_eq(transitions.size(), 1, "state_changed must fire once per real transition")
	assert_eq(transitions[0][0], &"idle")
	assert_eq(transitions[0][1], &"move")
	assert_eq(machine.current_state_name(), &"move")


func test_exit_runs_before_the_next_enter() -> void:
	var machine := _build_machine([&"idle", &"move"], &"idle")
	machine.start()
	machine.transition_to(&"move")
	var idle := machine.get_state(&"idle") as CountingState
	var move := machine.get_state(&"move") as CountingState
	assert_eq(idle.trace, ["enter:idle", "exit:idle"], "the old state is exited first")
	assert_eq(move.trace, ["enter:move"])


func test_transition_payload_reaches_enter() -> void:
	var machine := _build_machine([&"idle", &"dead"], &"idle")
	machine.start()
	machine.transition_to(&"dead", {"reason": &"collapsed_floor"})
	var dead := machine.get_state(&"dead") as CountingState
	assert_eq(dead.enter_messages.size(), 1)
	assert_eq((dead.enter_messages[0] as Dictionary).get("reason"), &"collapsed_floor", "states receive the transition payload")


func test_unknown_state_is_refused() -> void:
	var machine := _build_machine([&"idle"], &"idle")
	machine.start()
	assert_false(machine.transition_to(&"flying"), "an unknown state must be refused")
	assert_eq(machine.current_state_name(), &"idle", "a refused transition must not move the machine")


func test_transition_to_the_same_state_is_refused() -> void:
	var machine := _build_machine([&"idle"], &"idle")
	machine.start()
	assert_false(machine.transition_to(&"idle"))
	assert_eq((machine.get_state(&"idle") as CountingState).enter_messages.size(), 1, "enter() must not run twice")


func test_transition_before_start_is_refused() -> void:
	var machine := _build_machine([&"idle", &"move"], &"idle")
	assert_false(machine.transition_to(&"move"), "callers must call start() first; a silent transition would hide a bug")
	assert_false(machine.is_started())


func test_nested_transition_inside_enter_is_refused() -> void:
	var machine := StateMachine.new()
	machine.log_transitions = false
	add_child(machine)
	var state := ReentrantState.new()
	state.name = "Reentrant"
	state.state_name = &"reentrant"
	machine.add_child(state)
	var move_state := CountingState.new()
	move_state.name = "move"
	move_state.state_name = &"move"
	machine.add_child(move_state)
	machine.initial_state_name = &"reentrant"
	machine.setup(_host)
	machine.start()
	assert_true(state.nested_transition_refused, "a transition requested during enter() must be refused")
	assert_eq(machine.current_state_name(), &"reentrant", "the machine must not be left half-transitioned")


func test_physics_update_reaches_only_the_active_state() -> void:
	var machine := _build_machine([&"idle", &"move"], &"idle")
	machine.start()
	var idle := machine.get_state(&"idle") as CountingState
	var move := machine.get_state(&"move") as CountingState

	machine._physics_process(0.016)
	machine._physics_process(0.016)
	assert_eq(idle.physics_calls, 2, "gameplay logic belongs in physics_update")
	assert_eq(move.physics_calls, 0, "inactive states must not tick")

	machine.transition_to(&"move")
	machine._physics_process(0.016)
	assert_eq(idle.physics_calls, 2, "the previous state stops ticking")
	assert_eq(move.physics_calls, 1)


func test_idle_update_is_dispatched_too() -> void:
	var machine := _build_machine([&"idle"], &"idle")
	machine.start()
	machine._process(0.016)
	assert_eq((machine.get_state(&"idle") as CountingState).update_calls, 1)


func test_bad_initial_state_does_not_crash() -> void:
	var machine := _build_machine([&"idle"], &"nope")
	machine.start()
	assert_false(machine.is_started(), "a typo in initial_state_name must fail loudly but safely")
	assert_eq(machine.current_state_name(), &"", "the machine must stay usable after a bad start()")


func test_state_without_a_name_is_ignored() -> void:
	var machine := StateMachine.new()
	machine.log_transitions = false
	add_child(machine)
	var nameless := CountingState.new()
	nameless.name = "Nameless"
	machine.add_child(nameless)
	machine.initial_state_name = &"idle"
	machine.setup(_host)
	assert_false(machine.state_names().has(&""), "a state without a name must not be registered")
	assert_false(machine.has_state(&""))
	machine.start()
	assert_false(machine.is_started(), "with no valid state there is nothing to enter")


func test_debug_line_reports_current_state_and_the_full_set() -> void:
	var machine := _build_machine([&"idle", &"move"], &"idle")
	machine.start()
	assert_true(machine.debug_line().contains("idle"), "the debug overlay prints this")
	assert_true(machine.debug_line().contains("move"))


func test_duplicate_state_names_do_not_break_the_machine() -> void:
	var machine := StateMachine.new()
	machine.log_transitions = false
	add_child(machine)
	for index: int in 2:
		var duplicate := CountingState.new()
		duplicate.state_name = &"idle"
		duplicate.name = "Idle%d" % index
		machine.add_child(duplicate)
	machine.initial_state_name = &"idle"
	machine.setup(_host)
	machine.start()
	assert_true(machine.is_started(), "duplicates are a bug, but must not crash the machine")


func _build_machine(state_names: Array[StringName], initial_state: StringName) -> StateMachine:
	var machine := StateMachine.new()
	# Keep the test log quiet and dispatch explicitly so call counts are exact.
	machine.log_transitions = false
	add_child(machine)
	machine.set_process(false)
	machine.set_physics_process(false)
	for name_to_use: StringName in state_names:
		var state := CountingState.new()
		state.name = String(name_to_use)
		state.state_name = name_to_use
		machine.add_child(state)
	machine.initial_state_name = initial_state
	machine.setup(_host)
	_machine = machine
	return machine
