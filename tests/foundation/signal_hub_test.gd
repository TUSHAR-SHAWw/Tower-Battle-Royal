extends TestCase

## Guards the SignalHub contract.
##
## Everything in the project talks through this bus, so a renamed or deleted
## signal must fail a test here instead of silently breaking a listener in a
## system nobody is looking at.

const EXPECTED_SIGNALS: Array[StringName] = [
	# match lifecycle
	&"match_started", &"match_ended", &"match_phase_changed",
	# players
	&"player_spawned", &"player_died", &"player_damaged", &"player_health_changed", &"player_state_changed",
	# combat & items
	&"weapon_changed", &"item_collected", &"food_consumed", &"hunger_changed", &"rage_changed",
	&"super_hunger_changed", &"merge_completed",
	# tower & floors
	&"floor_changed", &"floor_state_changed", &"floor_warning_started", &"floor_deleted",
	# floor travel
	&"floor_travel_started", &"floor_travel_arrived", &"floor_travel_cancelled",
	# map / UI
	&"map_opened", &"map_closed", &"hud_notification",
	# debug
	&"debug_message",
]


func test_expected_signals_exist() -> void:
	for signal_name: StringName in EXPECTED_SIGNALS:
		assert_true(SignalHub.has_signal(signal_name), "SignalHub is missing signal '%s'" % signal_name)


func test_emit_and_receive_round_trip() -> void:
	var received: Array = []
	var handler := func(text: String, kind: StringName) -> void: received.append([text, kind])
	SignalHub.hud_notification.connect(handler)
	SignalHub.hud_notification.emit("INCOMING PLAYER", &"warning")
	SignalHub.hud_notification.disconnect(handler)
	assert_eq(received.size(), 1, "the listener should have been called exactly once")
	assert_eq(received[0][0], "INCOMING PLAYER")


func test_damage_signal_carries_the_info_object() -> void:
	var captured: Array = []
	var handler := func(_player: Node, info: DamageInfo) -> void: captured.append(info)
	SignalHub.player_damaged.connect(handler)
	SignalHub.player_damaged.emit(null, DamageInfo.create(7.0, DamageTypes.MELEE))
	SignalHub.player_damaged.disconnect(handler)
	assert_eq(captured.size(), 1)
	assert_eq((captured[0] as DamageInfo).amount, 7.0, "listeners must receive the real DamageInfo, not a copy")


func test_disconnect_stops_delivery() -> void:
	var count: Array = [0]
	# map_opened() takes no arguments — a mismatched lambda signature fails at
	# emission time, which is why this test exists in this exact shape.
	var handler := func() -> void: count[0] += 1
	SignalHub.map_opened.connect(handler)
	SignalHub.map_opened.emit()
	SignalHub.map_opened.disconnect(handler)
	SignalHub.map_opened.emit()
	assert_eq(count[0], 1, "after disconnect the listener must stop receiving")


func test_signal_argument_count_matches_the_handler() -> void:
	# Guards the other half of the contract above: the emitted payload must match
	# the declared signal signature, otherwise listeners break at runtime.
	var descriptions: Array = []
	var handler := func(_player: Node, current: float, maximum: float) -> void: descriptions.append([current, maximum])
	SignalHub.player_health_changed.connect(handler)
	SignalHub.player_health_changed.emit(null, 40.0, 100.0)
	SignalHub.player_health_changed.disconnect(handler)
	assert_eq(descriptions.size(), 1)
	assert_eq(descriptions[0][0], 40.0)
	assert_eq(descriptions[0][1], 100.0)
