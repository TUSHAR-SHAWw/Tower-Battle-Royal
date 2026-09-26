class_name DailyRewardComponent
extends Node

## Handles daily login rewards with streak escalation.

signal reward_claimed(day: int, rewards: Array[Dictionary])
signal streak_broken(old_streak: int)
signal reward_available()

@export var rewards: Array[Dictionary] = []  # Each day's rewards
@export var streak: int = 0
@export var last_claim_date: String = ""  # YYYY-MM-DD
@export var max_streak: int = 7

func _ready() -> void:
	_setup_default_rewards()


func _setup_default_rewards() -> void:
	if rewards.is_empty():
		rewards = [
			{"type": "gold", "amount": 100},
			{"type": "gold", "amount": 150},
			{"type": "gold", "amount": 200},
			{"type": "item", "item_id": "health_pack", "count": 1},
			{"type": "gold", "amount": 300},
			{"type": "item", "item_id": "adrenaline", "count": 1},
			{"type": "item", "item_id": "gold", "count": 500},  # streak 7 bonus
		]


func can_claim() -> bool:
	var today := Time.get_datetime_dict_from_system()
	var today_str := "%04d-%02d-%02d" % [today.year, today.month, today.day]
	return last_claim_date != today_str


func claim() -> Array[Dictionary]:
	if not can_claim():
		return []
	
	var today := Time.get_datetime_dict_from_system()
	var today_str := "%04d-%02d-%02d" % [today.year, today.month, today.day]
	
	# Check if streak continues
	var yesterday := Time.get_datetime_dict_from_system()
	yesterday.day -= 1
	var yesterday_str := "%04d-%02d-%02d" % [yesterday.year, yesterday.month, yesterday.day]
	
	if last_claim_date == yesterday_str:
		streak = min(streak + 1, max_streak)
	else:
		if last_claim_date != "":
			streak_broken.emit(streak)
		streak = 1
	
	last_claim_date = today_str
	
	# Get rewards for this streak day (wrap at max_streak)
	var day_index: int = min(streak - 1, rewards.size() - 1)
	var day_rewards: Array[Dictionary] = [rewards[day_index].duplicate(true)]
	
	reward_claimed.emit(streak, day_rewards)
	SignalHub.daily_reward_claimed.emit(streak, day_rewards)
	
	return day_rewards


func get_next_reward_preview() -> Dictionary:
	if rewards.is_empty():
		return {}
	var idx: int = min(streak, rewards.size() - 1)
	return rewards[idx].duplicate(true)


func get_streak() -> int:
	return streak


func debug_line() -> String:
	return "daily: streak=%d last=%s claimable=%s" % [streak, last_claim_date, can_claim()]