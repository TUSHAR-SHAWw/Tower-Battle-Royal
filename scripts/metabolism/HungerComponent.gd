class_name HungerComponent
extends Node

## Handles hunger decay, thresholds, and starvation damage.
## Hungry players lose stats; starving players take damage over time.

signal hunger_changed(current: float, max: float)
signal threshold_crossed(new_level: int)  # 0=full, 1=peckish, 2=hungry, 3=starving
signal starving_damage(amount: float)

@export var max_hunger: float = 100.0
@export var current_hunger: float = 100.0
@export var decay_per_second: float = 0.5

@export_group("Thresholds (0-1 normalized)")
@export var peckish_threshold: float = 0.75    # 75%
@export var hungry_threshold: float = 0.5      # 50%
@export var starving_threshold: float = 0.0    # 0%

@export_group("Effects")
@export var starving_dps: float = 2.0          # damage per second when starving
@export var peckish_speed_mult: float = 0.95   # slight slowdown
@export var hungry_speed_mult: float = 0.85    # moderate slowdown
@export var starving_speed_mult: float = 0.6   # severe slowdown

@export_group("Rage Interaction")
@export var rage_gain_on_eat: float = 5.0      # rage gained when eating

var _level: int = 0  # 0=full, 1=peckish, 2=hungry, 3=starving
var _starve_timer: float = 0.0

func _ready() -> void:
	_update_level()


func _physics_process(delta: float) -> void:
	if current_hunger <= 0.0:
		# Starving - take damage
		_starve_timer += delta
		if _starve_timer >= 1.0:
			_starve_timer = 0.0
			starving_damage.emit(starving_dps)
			SignalHub.player_health_changed.emit(get_parent(), -starving_dps, 100.0)
	else:
		# Normal decay
		current_hunger = max(0.0, current_hunger - decay_per_second * delta)
		_starve_timer = 0.0
	
	_update_level()
	hunger_changed.emit(current_hunger, max_hunger)


func _update_level() -> void:
	var norm := current_hunger / max_hunger
	var new_level: int
	
	if norm >= peckish_threshold:
		new_level = 0
	elif norm >= hungry_threshold:
		new_level = 1
	elif norm > starving_threshold:
		new_level = 2
	else:
		new_level = 3
	
	if new_level != _level:
		_level = new_level
		threshold_crossed.emit(_level)
		SignalHub.hunger_threshold_crossed.emit(_level)


func eat(amount: float) -> float:
	var before := current_hunger
	current_hunger = min(max_hunger, current_hunger + amount)
	return current_hunger - before


func get_level() -> int:
	return _level


func get_level_name() -> String:
	match _level:
		0: return "Full"
		1: return "Peckish"
		2: return "Hungry"
		3: return "Starving"
	return "Unknown"


func get_speed_multiplier() -> float:
	match _level:
		0: return 1.0
		1: return peckish_speed_mult
		2: return hungry_speed_mult
		3: return starving_speed_mult
	return 1.0


func debug_line() -> String:
	return "hunger: %.1f/%.1f (%s)" % [current_hunger, max_hunger, get_level_name()]