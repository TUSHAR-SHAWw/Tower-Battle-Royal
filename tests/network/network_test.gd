extends TestCase

## Tests for the networking layer: message types, serialization, and interpolation.

func test_network_types_constants() -> void:
	assert_eq(NetworkTypes.PORT, 7777)
	assert_eq(NetworkTypes.MAX_CLIENTS, 32)
	assert_eq(NetworkTypes.TICK_RATE, 60)

func test_message_type_enum() -> void:
	assert_eq(NetworkTypes.MessageType.HELLO, 1)
	assert_eq(NetworkTypes.MessageType.WELCOME, 2)
	assert_eq(NetworkTypes.MessageType.SNAPSHOT, 11)
	assert_eq(NetworkTypes.MessageType.PING, 14)
	assert_eq(NetworkTypes.MessageType.PONG, 15)

func test_entity_type_enum() -> void:
	assert_eq(NetworkTypes.EntityType.PLAYER, 1)
	assert_eq(NetworkTypes.EntityType.ENEMY, 2)
	assert_eq(NetworkTypes.EntityType.BOSS, 3)
	assert_eq(NetworkTypes.EntityType.PROJECTILE, 4)
	assert_eq(NetworkTypes.EntityType.PICKUP, 5)

func test_net_id_generation() -> void:
	NetworkTypes.reset_net_ids()
	var id1 := NetworkTypes.generate_net_id()
	var id2 := NetworkTypes.generate_net_id()
	assert_eq(id1, 1)
	assert_eq(id2, 2)
	NetworkTypes.reset_net_ids()

func test_net_message_create() -> void:
	var msg := NetMessage.create(NetworkTypes.MessageType.PING, 10, 5)
	assert_eq(msg.message_type, NetworkTypes.MessageType.PING)
	assert_eq(msg.tick, 10)
	assert_eq(msg.sender_id, 5)
	assert_false(msg.reliable)

func test_net_player_input_serialization() -> void:
	var input := NetMessage.NetPlayerInput.new()
	input.net_id = 1
	input.input_sequence = 42
	input.move_dir = Vector2(0.5, 0.5)
	input.aim_dir = Vector2.RIGHT
	input.fire_held = true
	input.fire_pressed = false
	input.sprint_held = true

	assert_eq(input.net_id, 1)
	assert_eq(input.input_sequence, 42)
	assert_true(input.fire_held)
	assert_true(input.sprint_held)
	assert_false(input.fire_pressed)

func test_net_snapshot_creation() -> void:
	var snap := NetMessage.NetSnapshot.new()
	snap.server_tick = 100
	snap.player_states = []
	snap.enemy_states = []

	assert_eq(snap.server_tick, 100)
	assert_eq(snap.player_states.size(), 0)

func test_net_player_state_defaults() -> void:
	var state := NetMessage.NetPlayerState.new()
	assert_eq(state.net_id, 0)
	assert_eq(state.health, 100.0)
	assert_eq(state.max_health, 100.0)
	assert_eq(state.state, &"idle")
	assert_vector_almost_eq(state.aim_direction, Vector2.RIGHT)

func test_snapshot_interpolator_creation() -> void:
	var interp := SnapshotInterpolator.new()
	interp.set_tick_rate(60)
	assert_eq(interp.get_pending_spawns().size(), 0)
	assert_eq(interp.get_pending_despawns().size(), 0)

func test_input_prediction_creation() -> void:
	var pred := InputPrediction.new()
	pred.set_tick_rate(60)
	assert_eq(pred.get_history_since(0).size(), 0)

func test_network_config_exists() -> void:
	var config := load("res://resources/network/default_config.tres") as NetworkConfig
	assert_not_null(config)
	if config != null:
		assert_eq(config.port, 7777)
		assert_true(config.prediction_enabled)
