class_name BattlePassResource
extends Resource

## Battle pass configuration with tiers and rewards.

@export var pass_name: String = "Season Pass"
@export var season_id: StringName = &"season_1"
@export var tiers: Array[BattlePassTier] = []
@export var xp_per_tier: int = 1000
@export var max_tier: int = 50
@export var premium_price: int = 1000  # gold or real currency

func _ready() -> void:
	_setup_default_tiers()


func _setup_default_tiers() -> void:
	if tiers.is_empty():
		for i in range(1, max_tier + 1):
			var tier := BattlePassTier.new()
			tier.tier = i
			tier.xp_required = i * xp_per_tier
			tier.is_milestone = (i % 5 == 0)
			
			# Free rewards (every tier)
			if tier.is_milestone:
				tier.free_reward = {"type": "gold", "amount": 200}
			else:
				tier.free_reward = {"type": "gold", "amount": 50}
			
			# Premium rewards (milestones get skins/items)
			if tier.is_milestone:
				var skin_ids := ["crimson_elite", "frost_walker", "void_stalker", "golden_king"]
				var idx := (i / 5 - 1) % skin_ids.size()
				tier.premium_reward = {"type": "skin", "item_id": skin_ids[idx]}
			else:
				tier.premium_reward = {"type": "gold", "amount": 200}
			
			tiers.append(tier)


func get_tier(tier_num: int) -> BattlePassTier:
	if tier_num >= 1 and tier_num <= tiers.size():
		return tiers[tier_num - 1]
	return null


func get_rewards_for_tier(tier_num: int, is_premium: bool) -> Dictionary:
	var tier := get_tier(tier_num)
	if tier == null:
		return {}
	
	var result: Dictionary = {}
	result.free = tier.free_reward.duplicate(true)
	if is_premium:
		result.premium = tier.premium_reward.duplicate(true)
	return result


func validate() -> Array[String]:
	var problems: Array[String] = []
	if pass_name.is_empty():
		problems.append("pass_name cannot be empty")
	if max_tier < 1:
		problems.append("max_tier must be >= 1")
	if xp_per_tier <= 0:
		problems.append("xp_per_tier must be > 0")
	return problems