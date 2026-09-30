class_name NetMessage
extends RefCounted

## Base network message structure.

var message_type: int = NetworkTypes.MessageType.NONE
var tick: int = 0
var sender_id: int = 0
var reliable: bool = false

func _init(p_type: int = NetworkTypes.MessageType.NONE) -> void:
	message_type = p_type

static func create(p_type: int, p_tick: int = 0, p_sender: int = 0) -> NetMessage:
	var msg := NetMessage.new()
	msg.message_type = p_type
	msg.tick = p_tick
	msg.sender_id = p_sender
	return msg


class NetHello: 
	var client_version: String = "1.0"
	var player_name: String = "Player"
	var platform: String = "PC"


class NetWelcome: 
	var client_id: int = 0
	var server_tick: int = 0
	var max_players: int = NetworkTypes.MAX_CLIENTS


class NetPlayerSpawn:
	var net_id: int = 0
	var player_id: int = 0
	var position: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var skin_id: StringName = &"default"
	var is_local: bool = false


class NetPlayerDespawn:
	var net_id: int = 0
	var reason: String = ""


class NetPlayerState:
	var net_id: int = 0
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var aim_direction: Vector2 = Vector2.RIGHT
	var state: StringName = &"idle"
	var health: float = 100.0
	var max_health: float = 100.0
	var is_sprinting: bool = false


class NetPlayerInput:
	var net_id: int = 0
	var input_sequence: int = 0
	var move_dir: Vector2 = Vector2.ZERO
	var aim_dir: Vector2 = Vector2.RIGHT
	var fire_held: bool = false
	var fire_pressed: bool = false
	var melee_pressed: bool = false
	var sprint_held: bool = false
	var reload_pressed: bool = false
	var use_pressed: bool = false
	var tick: int = 0


class NetEnemySpawn:
	var net_id: int = 0
	var enemy_id: StringName = &"grunt"
	var position: Vector2 = Vector2.ZERO
	var floor: int = 1


class NetEnemyDespawn:
	var net_id: int = 0


class NetEnemyState:
	var net_id: int = 0
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var state: StringName = &"idle"
	var target_net_id: int = 0
	var health: float = 50.0


class NetSnapshot:
	var server_tick: int = 0
	var player_states: Array = []
	var enemy_states: Array = []
	var projectile_states: Array = []


class NetInputAck:
	var client_id: int = 0
	var sequence: int = 0
	var accepted: bool = true