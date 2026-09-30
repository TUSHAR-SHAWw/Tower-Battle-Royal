class_name NetworkTypes
extends Resource

## Shared network types and constants.

const PORT: int = 7777
const MAX_CLIENTS: int = 32
const TICK_RATE: int = 60
const SNAPSHOT_RATE: int = 20  # snapshots per second
const MAX_SNAPSHOTS: int = 128
const INPUT_HISTORY_SIZE: int = 128

## Message types
enum MessageType {
	NONE = 0,
	HELLO = 1,
	WELCOME = 2,
	PLAYER_SPAWN = 3,
	PLAYER_DESPAWN = 4,
	PLAYER_STATE = 5,
	PLAYER_INPUT = 6,
	ENEMY_SPAWN = 7,
	ENEMY_DESPAWN = 8,
	ENEMY_STATE = 9,
	WORLD_STATE = 10,
	SNAPSHOT = 11,
	INPUT_ACK = 12,
	RPC = 13,
	PING = 14,
	PONG = 15,
	DISCONNECT = 16,
}

## Entity types for replication
enum EntityType {
	PLAYER = 1,
	ENEMY = 2,
	BOSS = 3,
	PROJECTILE = 4,
	PICKUP = 5,
}

## Compression settings
const POSITION_PRECISION: float = 0.1  # cm precision
const ROTATION_PRECISION: float = 0.01  # ~0.5 degree precision
const VELOCITY_PRECISION: float = 1.0  # px/s precision

## Returns a unique network ID for new entities.
static var _next_net_id: int = 1

static func generate_net_id() -> int:
	var id := _next_net_id
	_next_net_id += 1
	return id

static func reset_net_ids() -> void:
	_next_net_id = 1