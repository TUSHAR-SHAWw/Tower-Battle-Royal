extends TestCase

## GameState is what every UI and system asks "is the match live?", so its phase
## machine, clock and player counters are tested against the signals it emits.


func before_each() -> void:
	GameState.reset()


func after_suite() -> void:
	GameState.reset()


func test_defaults_are_idle() -> void:
	assert_eq(GameState.phase, GameState.MatchPhase.IDLE)
	assert_false(GameState.is_running(), "a fresh state must not report a live match")
	assert_eq(GameState.remaining_time(), 0.0)
	assert_eq(GameState.players_total, 0)


func test_start_match_sets_running_and_emits_once() -> void:
	var durations: Array = []
	var handler := func(duration: float) -> void: durations.append(duration)
	SignalHub.match_started.connect(handler)
	GameState.start_match(120.0, 8)
	SignalHub.match_started.disconnect(handler)

	assert_true(GameState.is_running())
	assert_eq(durations.size(), 1, "match_started must fire exactly once")
	assert_almost_eq(durations[0], 120.0)
	assert_eq(GameState.players_alive, 8)
	assert_almost_eq(GameState.remaining_time(), 120.0)


func test_phase_change_reports_previous_and_new() -> void:
	var transitions: Array = []
	var handler := func(phase: int, previous: int) -> void: transitions.append([previous, phase])
	SignalHub.match_phase_changed.connect(handler)
	GameState.start_match(60.0)
	GameState.set_phase(GameState.MatchPhase.ENDED)
	SignalHub.match_phase_changed.disconnect(handler)

	assert_eq(transitions.size(), 2, "IDLE->RUNNING then RUNNING->ENDED")
	assert_eq(transitions[0][0], int(GameState.MatchPhase.IDLE))
	assert_eq(transitions[0][1], int(GameState.MatchPhase.RUNNING))
	assert_eq(transitions[1][0], int(GameState.MatchPhase.RUNNING))
	assert_eq(transitions[1][1], int(GameState.MatchPhase.ENDED))


func test_setting_the_same_phase_does_not_emit() -> void:
	var emissions: Array = []
	var handler := func(_phase: int, _previous: int) -> void: emissions.append(1)
	SignalHub.match_phase_changed.connect(handler)
	GameState.set_phase(GameState.MatchPhase.LOADING)
	GameState.set_phase(GameState.MatchPhase.LOADING)
	SignalHub.match_phase_changed.disconnect(handler)
	assert_eq(emissions.size(), 1, "no signal when the phase does not actually change")


func test_clock_advances_only_while_running() -> void:
	GameState.match_duration = 10.0
	GameState.set_phase(GameState.MatchPhase.PREPARING)
	GameState._process(5.0)
	assert_almost_eq(GameState.match_elapsed, 0.0, "clock must stay frozen outside RUNNING")

	GameState.set_phase(GameState.MatchPhase.RUNNING)
	GameState._process(5.0)
	assert_almost_eq(GameState.match_elapsed, 5.0)
	assert_almost_eq(GameState.remaining_time(), 5.0)


func test_elapsed_clamps_to_duration() -> void:
	GameState.start_match(10.0)
	GameState._process(30.0)
	assert_almost_eq(GameState.match_elapsed, 10.0, "elapsed must clamp at match_duration")
	assert_almost_eq(GameState.remaining_time(), 0.0)


func test_player_counters_never_go_negative() -> void:
	GameState.start_match(60.0, 2)
	assert_eq(GameState.notify_player_eliminated(), 1)
	assert_eq(GameState.notify_player_eliminated(), 0)
	assert_eq(GameState.notify_player_eliminated(), 0, "alive count must clamp at zero")
	assert_eq(GameState.notify_player_spawned(), 1)
	assert_eq(GameState.players_total, 3, "total counts every spawn, including late joins")


func test_reset_clears_everything() -> void:
	GameState.start_match(60.0, 4)
	GameState.tower_floor_count = 12
	GameState.reset()
	assert_eq(GameState.phase, GameState.MatchPhase.IDLE)
	assert_eq(GameState.players_total, 0)
	assert_eq(GameState.players_alive, 0)
	assert_eq(GameState.tower_floor_count, 0)
	assert_almost_eq(GameState.remaining_time(), 0.0)


func test_phase_name_is_human_readable() -> void:
	GameState.set_phase(GameState.MatchPhase.RUNNING)
	assert_eq(GameState.phase_name(), "RUNNING", "the debug overlay prints this string")
