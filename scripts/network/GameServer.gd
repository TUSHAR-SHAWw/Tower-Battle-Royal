class_name GameServer
extends Node

## Server-authoritative match state.
##
## Runs the physics simulation, collects client inputs, broadcasts snapshots,
## and validates actions. In a standalone build this node owns the game;
## in a peer-to-peer fallback it takes ownership from the host client.

signal client_connected(client_id: int)
signal client_disconnected(client_id: int)
signal player_joined(client_id: int, player_name: String)

@export var listen_port: int = NetworkTypes.PORT
@export var max_clients: int = NetworkTypes.MAX_CLIENTS
@export var tick_rate: int = NetworkTypes.TICK_RATE
@export var snapshot_rate: int = NetworkTypes.SNAPSHOT_RATE

var _server: ENetMultiplayerPeer = null
var _clients: Dictionary[int, Dictionary] = {}
var _tick: int = 0
var _pending_inputs: Dictionary[int, Array] = {}
var _snapshot_buffer: Array[NetMessage.NetSnapshot] = []
var _players: Dictionary[int, Dictionary] = {}

var _tick_timer: SceneTreeTimer = null
var _snapshot_timer: SceneTreeTimer = null
var _world: Node2D = null

var _is_listening: bool = false


func _ready() -> void:
	_world = get_tree().get_root().get_node_or_null("Match") as Node2D
	if _world == null:
		_world = get_parent() as Node2D


func start_server() -> Error:
	if _is_listening:
		return ERR_ALREADY_IN_USE

	_server = ENetMultiplayerPeer.new()
	var err := _server.create_server(listen_port, max_clients)
	if err != OK:
		push_error("GameServer: failed to bind port %d (error %d)" % [listen_port, err])
		return err

	multiplayer.multiplayer_peer = _server
	_is_listening = true
	GameLog.info("GameServer", "Listening on port %d" % listen_port)

	_start_tick_loop()
	_start_snapshot_loop()

	return OK


func stop_server() -> void:
	if not _is_listening:
		return
	_server = null
	multiplayer.multiplayer_peer = null
	_is_listening = false
	_clients.clear()
	_players.clear()
	_stop_loops()


func _start_tick_loop() -> void:
	var tick_interval := 1.0 / float(tick_rate)
	_tick_timer = get_tree().create_timer(tick_interval, true, true, false)
	_tick_timer.timeout.connect(_on_tick)


func _start_snapshot_loop() -> void:
	var snapshot_interval := 1.0 / float(snapshot_rate)
	_snapshot_timer = get_tree().create_timer(snapshot_interval, true, true, false)
	_snapshot_timer.timeout.connect(_on_snapshot_tick)


func _stop_loops() -> void:
	if _tick_timer != null:
		_tick_timer.timeout.disconnect(_on_tick)
		_tick_timer = null
	if _snapshot_timer != null:
		_snapshot_timer.timeout.disconnect(_on_snapshot_tick)
		_snapshot_timer = null


func _on_tick() -> void:
	_tick += 1

	# Apply all queued inputs for this tick
	for client_id: int in _pending_inputs.keys():
		var input_list: Array = _pending_inputs[client_id]
		for input: NetMessage.NetPlayerInput in input_list:
			if input.tick <= _tick:
				_apply_input(client_id, input)
		_pending_inputs[client_id].clear()

	# Physics step is driven by the engine; we just advance game logic
	_process_world_tick()
	_collect_inputs()


func _collect_inputs() -> void:
	# Gather current state of all players for this tick
	for client_id: int in _players.keys():
		var player_info := _players[client_id]
		var player_node: Node = player_info.get("node", null)
		if player_node == null:
			continue
		player_info["last_seen_tick"] = _tick


func _process_world_tick() -> void:
	# The actual physics simulation runs via _physics_process.
	# This hook is for game-level tick logic (spawning, timers, etc.).
	pass


func _apply_input(client_id: int, input: NetMessage.NetPlayerInput) -> void:
	var player_info := _players.get(client_id, {})
	var player_node: Node = player_info.get("node", null)
	if player_node == null:
		return

	var driver := player_node.get_node_or_null("NetworkInputDriver") as NetworkInputDriver
	if driver == null:
		return

	driver.queue_input(input)


func _on_snapshot_tick() -> void:
	var snapshot := NetMessage.NetSnapshot.create(NetworkTypes.MessageType.SNAPSHOT)
	snapshot.server_tick = _tick

	for client_id: int in _players.keys():
		var player_info := _players[client_id]
		var player_node: Node = player_info.get("node", null)
		if player_node == null:
			continue

		var state := NetMessage.NetPlayerState.new()
		state.net_id = client_id
		state.position = player_node.global_position
		state.velocity = (player_node as CharacterBody2D).velocity if player_node is CharacterBody2D else Vector2.ZERO
		state.rotation = player_node.rotation
		var health_comp := player_node.get_node_or_null("HealthComponent") as HealthComponent
		state.health = health_comp.current_health if health_comp != null else 100.0
		state.max_health = health_comp.max_health if health_comp != null else 100.0

		var state_machine := player_node.get_node_or_null("StateMachine") as StateMachine
		if state_machine != null:
			state.state = state_machine.current_state_name()
		else:
			state.state = &"idle"

		var visual := player_node.get_node_or_null("Visual")
		if visual != null and visual.has_method("get_aim_direction"):
			state.aim_direction = visual.get_aim_direction()

		snapshot.player_states.append(state)

	# Also snapshot enemies
	var enemies: Array[Node] = []
	if _world != null:
		enemies = _world.get_nodes_in_group(&"enemies")
	for enemy in enemies:
		if enemy.has_method("get_net_state"):
			snapshot.enemy_states.append(enemy.get_net_state())

	_snapshot_buffer.append(snapshot)
	if _snapshot_buffer.size() > NetworkTypes.MAX_SNAPSHOTS:
		_snapshot_buffer.pop_front()

	_broadcast_snapshot(snapshot)


func _broadcast_snapshot(snapshot: NetMessage.NetSnapshot) -> void:
	for client_id: int in _clients.keys():
		rpc_id(client_id, "_client_receive_snapshot", _serialize_snapshot(snapshot))


func _serialize_snapshot(snapshot: NetMessage.NetSnapshot) -> Dictionary:
	var player_states: Array[Dictionary] = []
	for s: NetMessage.NetPlayerState in snapshot.player_states:
		player_states.append({
			"net_id": s.net_id,
			"position": s.position,
			"velocity": s.velocity,
			"rotation": s.rotation,
			"aim_direction": s.aim_direction,
			"state": s.state,
			"health": s.health,
			"max_health": s.max_health,
			"is_sprinting": s.is_sprinting,
		})

	var enemy_states: Array[Dictionary] = []
	for s: NetMessage.NetEnemyState in snapshot.enemy_states:
		enemy_states.append({
			"net_id": s.net_id,
			"position": s.position,
			"velocity": s.velocity,
			"state": s.state,
			"target_net_id": s.target_net_id,
			"health": s.health,
		})

	return {
		"server_tick": snapshot.server_tick,
		"player_states": player_states,
		"enemy_states": enemy_states,
	}


@rpc("any_peer", "unreliable")
func _receive_client_input(serialized: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 1:
		return

	var input := NetMessage.NetPlayerInput.new()
	input.net_id = sender_id
	input.input_sequence = serialized.input_sequence
	input.tick = serialized.tick
	input.move_dir = serialized.move_dir
	input.aim_dir = serialized.aim_dir
	input.fire_held = serialized.fire_held
	input.fire_pressed = serialized.fire_pressed
	input.melee_pressed = serialized.melee_pressed
	input.sprint_held = serialized.sprint_held
	input.reload_pressed = serialized.reload_pressed
	input.use_pressed = serialized.use_pressed
	input.tick = _tick

	if not _pending_inputs.has(sender_id):
		_pending_inputs[sender_id] = []
	_pending_inputs[sender_id].append(input)


@rpc("authority", "reliable")
func _client_receive_snapshot(data: Dictionary) -> void:
	pass


func _on_client_connected(id: int) -> void:
	_clients[id] = {"connected_at": Time.get_unix_from_system() }
	_is_ready_for_player(id)


func _on_client_disconnected(id: int) -> void:
	_clients.erase(id)
	_players.erase(id)


func _is_ready_for_player(client_id: int) -> void:
	var client_data := _clients.get(client_id, {})
	if not client_data.has("hello_received"):
		return
	client_data["hello_received"] = true

	client_connected.emit(client_id)


func assign_player(client_id: int, player_name: String) -> int:
	var net_id := NetworkTypes.generate_net_id()
	_players[client_id] = {
		"net_id": net_id,
		"player_name": player_name,
		"node": null,
		"joined_at": _tick,
	}

	player_joined.emit(client_id, player_name)

	# Notify all clients about the new player
	rpc("_client_spawn_player", net_id, player_name)

	return net_id


func get_player_node(client_id: int) -> Node:
	var info := _players.get(client_id, {})
	return info.get("node", null) as Node


func get_tick() -> int:
	return _tick


func get_snapshot_history() -> Array[NetMessage.NetSnapshot]:
	return _snapshot_buffer.duplicate(true)


func has_player_spawned(client_id: int) -> bool:
	return _players.has(client_id) and _players[client_id].has("node")


@rpc("authority", "reliable")
func _client_spawn_player(net_id: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	SignalHub.player_spawned_in_match.emit({
		"net_id": net_id,
		"player_id": net_id,
		"player_name": player_name,
		"tick": _tick,
	})
