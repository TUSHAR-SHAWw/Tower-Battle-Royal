class_name GameClient
extends Node

## Client-side network manager.
##
## Connects to a GameServer, sends inputs, receives snapshots, and
## reconciles/interpolates remote player state. Only the local player
## is simulated with input prediction; remote players are interpolated.

signal connected_to_server()
signal disconnected_from_server(reason: String)
signal server_tick_updated(tick: int)
signal player_spawned(net_id: int, player_name: String, is_local: bool)

@export var server_address: String = "127.0.0.1"
@export var server_port: int = NetworkTypes.PORT

var _multiplayer := MultiplayerAPI.new()
var _client_id: int = 0
var _local_net_id: int = 0
var _server_tick: int = 0
var _connected: bool = false

var _input_sequence: int = 0
var _pending_inputs: Array[Dictionary] = []
var _last_acked_sequence: int = 0
var _rtt: float = 0.0
var _ping_time: float = 0.0

var _snapshot_interpolator := SnapshotInterpolator.new()
var _prediction := InputPrediction.new()

var _tick_rate: int = NetworkTypes.TICK_RATE
var _snapshot_rate: int = NetworkTypes.SNAPSHOT_RATE


func _ready() -> void:
	_snapshot_interpolator.set_tick_rate(_tick_rate)
	_prediction.set_tick_rate(_tick_rate)


func connect_to_server(address: String = server_address, port: int = server_port) -> Error:
	if _connected:
		return ERR_ALREADY_IN_USE

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("GameClient: connection failed: %d" % err)
		return err

	_multiplayer.multiplayer_peer = peer
	_connected = true

	_multiplayer.connected_to_server.connect(_on_connected)
	_multiplayer.connection_failed.connect(_on_connection_failed)
	_multiplayer.server_disconnected.connect(_on_server_disconnected)

	return OK


func disconnect_from_server() -> void:
	if not _connected:
		return
	_multiplayer.multiplayer_peer = null
	_connected = false
	_client_id = 0


func is_connected_to_server() -> bool:
	return _connected


func send_hello(player_name: String) -> void:
	rpc_id(1, "_receive_hello", {
		"client_version": "1.0",
		"player_name": player_name,
		"platform": OS.get_name(),
	})


func send_input(intent: InputIntent) -> void:
	if not _connected:
		return

	_input_sequence += 1
	var seq := _input_sequence

	var serialized := {
		"net_id": _local_net_id,
		"input_sequence": seq,
		"move_dir": intent.move_dir,
		"aim_dir": intent.aim_dir,
		"fire_held": intent.fire_held,
		"fire_pressed": intent.fire_pressed,
		"melee_pressed": intent.melee_pressed,
		"sprint_held": intent.sprint_held,
		"reload_pressed": intent.reload_pressed,
		"use_pressed": intent.interact_pressed,
		"tick": _server_tick,
	}

	_pending_inputs.append(serialized)

	rpc_id(1, "_receive_client_input", serialized)


func _on_connected() -> void:
	connected_to_server.emit()
	send_hello("Player")


func _on_connection_failed() -> void:
	disconnected_from_server.emit("Connection failed")


func _on_server_disconnected() -> void:
	_connected = false
	disconnected_from_server.emit("Server disconnected")


@rpc("authority", "reliable")
func _welcome(client_id: int, server_tick: int, max_players: int) -> void:
	_client_id = client_id
	_local_net_id = client_id
	_server_tick = server_tick
	connected_to_server.emit()


@rpc("authority", "reliable")
func _client_spawn_player(net_id: int, player_name: String) -> void:
	player_spawned.emit(net_id, player_name, net_id == _local_net_id)


@rpc("authority", "reliable")
func _client_receive_snapshot(data: Dictionary) -> void:
	_server_tick = data.server_tick
	server_tick_updated.emit(_server_tick)

	var snapshot := NetMessage.NetSnapshot.new()
	snapshot.server_tick = data.server_tick

	for state_dict in data.player_states:
		var state := NetMessage.NetPlayerState.new()
		state.net_id = state_dict.net_id
		state.position = state_dict.position
		state.velocity = state_dict.velocity
		state.rotation = state_dict.rotation
		state.aim_direction = state_dict.aim_direction
		state.state = state_dict.state
		state.health = state_dict.health
		state.max_health = state_dict.max_health
		state.is_sprinting = state_dict.is_sprinting
		snapshot.player_states.append(state)

	for state_dict in data.enemy_states:
		var state := NetMessage.NetEnemyState.new()
		state.net_id = state_dict.net_id
		state.position = state_dict.position
		state.velocity = state_dict.velocity
		state.state = state_dict.state
		state.target_net_id = state_dict.target_net_id
		state.health = state_dict.health
		snapshot.enemy_states.append(state)

	_snapshot_interpolator.add_snapshot(snapshot)


func _process(delta: float) -> void:
	if not _connected:
		return
	_snapshot_interpolator.update(delta)


func get_local_net_id() -> int:
	return _local_net_id


func get_server_tick() -> int:
	return _server_tick


func get_rtt() -> float:
	return _rtt


func get_interpolator() -> SnapshotInterpolator:
	return _snapshot_interpolator


func get_prediction() -> InputPrediction:
	return _prediction
