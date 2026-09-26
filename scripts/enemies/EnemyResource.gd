class_name EnemyResource
extends Resource

## Data-driven enemy configuration. Lives in `resources/enemies/*.tres`.

@export_group("Identity")
@export var enemy_name: String = "Unnamed Enemy"
@export var enemy_id: StringName = &"unknown"
@export var description: String = ""

@export_group("Stats")
@export var max_health: float = 50.0
@export var move_speed: float = 100.0
@export var damage: float = 10.0
@export var damage_type: StringName = &"physical"
@export var knockback: float = 150.0
@export var xp_reward: int = 25
@export var gold_reward: int = 10

@export_group("Combat")
@export var attack_range: float = 32.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 0.5
@export var projectile_speed: float = 300.0
@export var is_ranged: bool = false

@export_group("Behavior")
@export var aggro_range: float = 300.0
@export var deaggro_range: float = 500.0
@export var patrol_radius: float = 150.0
@export var prefers_melee: bool = true

@export_group("Visuals")
@export var body_color: Color = Color(0.8, 0.3, 0.3, 1)
@export var size: float = 16.0
@export var has_shadow: bool = true

@export_group("Loot")
@export var loot_table: LootTable = null  # from loot system

@export_group("Scaling")
@export var health_per_floor: float = 5.0
@export var damage_per_floor: float = 1.0
@export var speed_per_floor: float = 2.0

func validate() -> Array[String]:
	var problems: Array[String] = []
	if enemy_name.is_empty():
		problems.append("enemy_name cannot be empty")
	if max_health <= 0:
		problems.append("max_health must be > 0")
	if move_speed < 0:
		problems.append("move_speed must be >= 0")
	if damage < 0:
		problems.append("damage must be >= 0")
	if attack_cooldown <= 0:
		problems.append("attack_cooldown must be > 0")
	return problems


func get_scaled_stats(floor: int) -> Dictionary:
	var result: Dictionary = {}
	result.max_health = max_health + health_per_floor * (floor - 1)
	result.damage = damage + damage_per_floor * (floor - 1)
	result.move_speed = move_speed + speed_per_floor * (floor - 1)
	result.xp_reward = xp_reward + floor * 5
	result.gold_reward = gold_reward + floor * 2
	return result