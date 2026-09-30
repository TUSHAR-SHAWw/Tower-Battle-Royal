class_name NetworkMatch
extends Node2D

## Network-aware match scene.
##
## In single-player / host mode: spawns a GameServer and acts as the
## authoritative simulation. In client mode: spawns a GameClient that
## connects to a remote server and reconciles state.
##
## The local player is always simulated with input prediction; remote
## players are interpolated from snapshots.

enum Mode {
	OFFLINE,
	DEDICATED_SERVER,
	HOST,
	CLIENT,
}

@export var mode: Mode = Mode.OFFLINE
@export var tower_data: Array[TowerData] = []
@export var initial_floor: int = 1

@onready var tower: TowerController = $TowerController
@onready var server: GameServer = $GameServer
@onready var client: GameClient = $GameClient

var _net_id_counter: int = 0
var _player_controllers: Dictionary[int, Node] = {}

var _local_mode: Mode = Mode.OFFLINE


func _ready() -> void:
	if mode == Mode.HOST or mode == Mode.DEDICATED_SERVER:
		_start_server()
	elif mode == Mode.CLIENT:
		_start_client()

	# TowerController takes the tower_data, initial_floor
	if tower_data.size() > 0:
		tower.tower_data = tower_data
		tower.initial_floor = initial_floor

	if mode != Mode.OFFLINE:
		# Wait for players to connect before starting
		if mode == Mode.DEDICATED_SERVER or mode == Mode.HOST:
			server.start_server()
		else:
			client.connect_to_server()


func _start_server() -> void:
	server.connect("client_connected", _on_server_client_connected)
	server.connect("player_joined", _on_server_player_joined)


func _start_client() -> void:
	client.connect("connected_to_server", _on_client_connected)
	client.connect("disconnected_from_server", _on_client_disconnected)
	client.connect("player_spawned", _on_client_player_spawned)


func _on_server_client_connected(client_id: int) -> void:
	GameLog.info("NetworkMatch", "Client %d connected" % client_id)


func _on_server_player_joined(client_id: int, player_name: String) -> void:
	var net_id := server.assign_player(client_id, player_name)
	_spawn_player_on_server(net_id, client_id, player_name, mode == Mode.HOST)


func _spawn_player_on_server(net_id: int, client_id: int, player_name: String, is_local: bool) -> void:
	var player_scene := preload("res://scenes/player/Player.tscn")
	var player := player_scene.instantiate() as Player

	player.name = "Player_%d" % net_id
	player.net_id = net_id
	player.is_local = is_local
	player.player_name = player_name

	if is_local and mode == Mode.HOST:
		player.input_source = player.get_node_or_null("InputDriver")
	else:
		# Remote players use NetworkInputDriver
		var net_driver := NetworkInputDriver.new()
		net_driver.name = "NetworkInputDriver"
		player.add_child(net_driver)
		player.input_source = net_driver

	var floor := tower.get_current_floor()
	if floor != null:
		player.global_position = floor.get_random_spawn_point()

	add_child(player)
	_player_controllers[net_id] = player

	# Register with server
	server._players[client_id]["node"] = player

	SignalHub.player_spawned_in_match.emit({
		"net_id": net_id,
		"player_id": net_id,
		"player_name": player_name,
		"tick": server.get_tick(),
	})


func _on_client_connected() -> void:
	GameLog.info("NetworkMatch", "Connected to server")
	client.send_hello("Player")


func _on_client_disconnected(reason: String) -> void:
	GameLog.info("NetworkMatch", "Disconnected: %s" % reason)


func _on_client_player_spawned(net_id: int, player_name: String, is_local: bool) -> void:
	var player_scene := preload("res://scenes/player/Player.tscn")
	var player := player_scene.instantiate() as Player

	player.name = "Player_%d" % net_id
	player.net_id = net_id
	player.is_local = is_local
	player.player_name = player_name

	if is_local:
		player.input_source = player.get_node_or_null("InputDriver")

	add_child(player)
	_player_controllers[net_id] = player


func _get_local_player() -> Player:
	for net_id: int in _player_controllers.keys():
		var p: Player = _player_controllers[net_id] as Player
		if p != null and p.is_local:
			return p
	return null


func _process(delta: float) -> void:
	if mode == Mode.CLIENT and client.is_connected_to_server():
		for net_id: int in _player_controllers.keys():
			var player: Node = _player_controllers[net_id]
			if player == null or not player.is_inside_tree():
				continue

			var interpolator := client.get_interpolator()
			if interpolator == null:
				continue

			if player.is_local:
				continue

			var state := interpolator.get_interpolated_state(net_id, client.get_server_tick())
			if state.size() > 0:
				player.call_deferred("_apply_network_state", state)
