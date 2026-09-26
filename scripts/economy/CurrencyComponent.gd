class_name CurrencyComponent
extends Node

## Manages player currencies: gold, XP, battle pass progress.

signal gold_changed(current: int, delta: int)
signal xp_changed(current: int, delta: int)
signal level_up(new_level: int)
signal battle_pass_xp_changed(current: int, delta: int)
signal battle_pass_tier_unlocked(tier: int, is_premium: bool)

@export var gold: int = 0
@export var xp: int = 0
@export var level: int = 1
@export var battle_pass_xp: int = 0
@export var battle_pass_tier: int = 0
@export var has_premium_pass: bool = false

# XP required per level (formula: base * level^1.5)
var _xp_base: int = 100

func _ready() -> void:
	pass


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	var old := gold
	gold = max(0, gold + amount)
	gold_changed.emit(gold, gold - old)
	SignalHub.gold_changed.emit(gold, gold - old)


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold, -amount)
	SignalHub.gold_changed.emit(gold, -amount)
	return true


func can_afford(amount: int) -> bool:
	return gold >= amount


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var old := xp
	xp += amount
	xp_changed.emit(xp, amount)
	SignalHub.xp_changed.emit(xp, amount)
	
	_check_level_up()
	
	# Also add to battle pass
	add_battle_pass_xp(amount)


func add_battle_pass_xp(amount: int) -> void:
	if amount <= 0:
		return
	var old := battle_pass_xp
	battle_pass_xp += amount
	battle_pass_xp_changed.emit(battle_pass_xp, amount)
	SignalHub.battle_pass_xp_changed.emit(battle_pass_xp, amount)
	
	_check_battle_pass_tiers()


func _check_level_up() -> void:
	var required := _xp_for_level(level + 1)
	while xp >= required:
		level += 1
		required = _xp_for_level(level + 1)
		level_up.emit(level)
		SignalHub.level_up.emit(level)


func _check_battle_pass_tiers() -> void:
	var max_tier := 50
	var xp_per_tier := 1000
	
	while battle_pass_tier < max_tier:
		var required := (battle_pass_tier + 1) * xp_per_tier
		if battle_pass_xp >= required:
			battle_pass_tier += 1
			battle_pass_tier_unlocked.emit(battle_pass_tier, false)
			if has_premium_pass:
				battle_pass_tier_unlocked.emit(battle_pass_tier, true)
				SignalHub.battle_pass_tier_unlocked.emit(battle_pass_tier, true)
			SignalHub.battle_pass_tier_unlocked.emit(battle_pass_tier, false)
		else:
			break


func _xp_for_level(lvl: int) -> int:
	return int(_xp_base * pow(lvl, 1.5))


func get_xp_for_next_level() -> int:
	return _xp_for_level(level + 1)


func get_xp_progress() -> float:
	var current_req := _xp_for_level(level)
	var next_req := _xp_for_level(level + 1)
	var progress := (xp - current_req) / (next_req - current_req)
	return clamp(progress, 0.0, 1.0)


func get_battle_pass_progress() -> float:
	var xp_per_tier := 1000
	var current_req := battle_pass_tier * xp_per_tier
	var next_req := (battle_pass_tier + 1) * xp_per_tier
	var progress := (battle_pass_xp - current_req) / (next_req - current_req)
	return clamp(progress, 0.0, 1.0)


func debug_line() -> String:
	return "economy: gold=%d xp=%d lvl=%d bp_tier=%d" % [gold, xp, level, battle_pass_tier]