class_name BattlePassComponent
extends Node

## Manages battle pass progression and rewards.

signal tier_unlocked(tier: int, is_premium: bool, rewards: Dictionary)
signal xp_added(amount: int)
signal premium_purchased()

@export var battle_pass: BattlePassResource
@export var current_tier: int = 0
@export var tier_xp: int = 0
@export var is_premium: bool = false
@export var claimed_tiers: Array[int] = []  # which tiers have been claimed

func _ready() -> void:
	pass


func add_xp(amount: int) -> void:
	if amount <= 0 or battle_pass == null:
		return
	
	tier_xp += amount
	xp_added.emit(amount)
	SignalHub.battle_pass_xp_changed.emit(tier_xp, amount)
	
	_check_tier_unlocks()


func _check_tier_unlocks() -> void:
	if battle_pass == null:
		return
	
	var xp_per_tier := battle_pass.xp_per_tier
	var max_tier := battle_pass.max_tier
	
	while current_tier < max_tier:
		var required := (current_tier + 1) * xp_per_tier
		if tier_xp >= required:
			current_tier += 1
			_unlock_tier(current_tier)
		else:
			break


func _unlock_tier(tier: int) -> void:
	if battle_pass == null:
		return
	
	# Auto-claim free rewards
	var free_reward := battle_pass.tiers[tier - 1].free_reward
	_grant_reward(free_reward)
	
	tier_unlocked.emit(tier, false, {"free": free_reward})
	
	# Premium reward
	if is_premium:
		var premium_reward := battle_pass.tiers[tier - 1].premium_reward
		_grant_reward(premium_reward)
		tier_unlocked.emit(tier, true, {"free": free_reward, "premium": premium_reward})


func _grant_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	
	var player := get_parent()
	var inv := player.get_node_or_null("InventoryComponent")
	var currency := player.get_node_or_null("CurrencyComponent")
	
	if reward.type == "gold" and currency != null:
		currency.add_gold(reward.amount)
	elif reward.type == "item" and inv != null:
		var item := load("res://resources/items/%s.tres" % reward.item_id)
		if item != null:
			inv.add_item(item, reward.count)
	elif reward.type == "skin" and inv != null:
		var skin := load("res://resources/skins/%s.tres" % reward.item_id)
		if skin != null:
			var locker := player.get_node_or_null("LockerComponent")
			if locker != null:
				locker.unlock_skin(skin)
				locker.equip_skin(skin)


func claim_tier(tier: int) -> bool:
	if battle_pass == null:
		return false
	if claimed_tiers.has(tier):
		return false
	if tier > current_tier:
		return false
	
	claimed_tiers.append(tier)
	
	var tier_data := battle_pass.tiers[tier - 1]
	var free_reward := tier_data.free_reward
	_grant_reward(free_reward)
	
	if is_premium:
		var premium_reward := tier_data.premium_reward
		_grant_reward(premium_reward)
	
	return true


func purchase_premium() -> bool:
	if is_premium:
		return false
	if battle_pass == null:
		return false
	
	var currency := get_parent().get_node_or_null("CurrencyComponent")
	if currency != null and currency.spend_gold(battle_pass.premium_price):
		is_premium = true
		premium_purchased.emit()
		SignalHub.battle_pass_premium_purchased.emit()
		
		# Claim all unlocked premium rewards retroactively
		for i in range(1, current_tier + 1):
			if not claimed_tiers.has(i):
				var tier_data := battle_pass.tiers[i - 1]
				var premium_reward := tier_data.premium_reward
				_grant_reward(premium_reward)
		
		return true
	return false


func get_progress() -> float:
	if battle_pass == null or battle_pass.max_tier <= 0:
		return 0.0
	return clamp(float(current_tier) / battle_pass.max_tier, 0.0, 1.0)


func get_tier_progress() -> float:
	if battle_pass == null:
		return 0.0
	var xp_per_tier := battle_pass.xp_per_tier
	var next_req := (current_tier + 1) * xp_per_tier
	if next_req <= 0:
		return 1.0
	return clamp(float(tier_xp) / next_req, 0.0, 1.0)


func debug_line() -> String:
	return "bp: tier=%d/%d xp=%d premium=%s" % [current_tier, battle_pass.max_tier if battle_pass else 0, tier_xp, is_premium]