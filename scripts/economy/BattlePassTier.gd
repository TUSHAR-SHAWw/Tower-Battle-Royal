class_name BattlePassTier
extends Resource

## A single tier in the battle pass.

@export var tier: int = 1
@export var xp_required: int = 1000
@export var free_reward: Dictionary = {}  # {"type": "gold", "amount": 100}
@export var premium_reward: Dictionary = {}  # {"type": "skin", "item_id": "crimson_elite"}
@export var is_milestone: bool = false  # Every 5 tiers = milestone with better rewards

func validate() -> Array[String]:
	var problems: Array[String] = []
	if tier < 1:
		problems.append("tier must be >= 1")
	if xp_required < 0:
		problems.append("xp_required must be >= 0")
	return problems