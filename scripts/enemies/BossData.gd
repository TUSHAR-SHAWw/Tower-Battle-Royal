class_name BossData
extends Resource

## Complete boss configuration.

@export var boss_name: String = "Unnamed Boss"
@export var boss_id: StringName = &"unknown"
@export var max_health: float = 500.0
@export var base_speed: float = 80.0
@export var base_damage: float = 30.0
@export var phases: Array[BossPhaseData] = []
@export var reward_xp: int = 500
@export var reward_gold: int = 200
@export var reward_items: Array[Dictionary] = []  # guaranteed drops

func validate() -> Array[String]:
	var problems: Array[String] = []
	if boss_name.is_empty():
		problems.append("boss_name cannot be empty")
	if max_health <= 0:
		problems.append("max_health must be > 0")
	if phases.is_empty():
		problems.append("at least 1 phase required")
	return problems