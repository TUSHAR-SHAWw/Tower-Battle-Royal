class_name NetworkConfig
extends Resource

## Network configuration resource for matches (M20).

@export_group("Connection")
@export var host: String = "127.0.0.1"
@export var port: int = NetworkTypes.PORT
@export var max_clients: int = NetworkTypes.MAX_CLIENTS

@export_group("Simulation")
@export var tick_rate: int = NetworkTypes.TICK_RATE
@export var snapshot_rate: int = NetworkTypes.SNAPSHOT_RATE
@export var interpolation_delay: float = 100.0  # ms
@export var prediction_enabled: bool = true

@export_group("Fallback")
@export var offline_enabled: bool = true
@export var bot_fill_enabled: bool = true
@export var max_bots: int = 0

const FALLBACK_LAN_DISCOVERY_PORT: int = 7776
