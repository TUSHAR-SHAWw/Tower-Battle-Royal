class_name RageComponent
extends Node

## Handles rage meter, thresholds, and rage mode.
## Rage builds from combat, grants damage/speed buffs when active.

signal rage_changed(current: float, max: float)
signal rage_mode_activated()
signal rage_mode_deactivated()

@export var max_rage: float = 100.0
@export var current_rage: float = 0.0
@export var decay_per_second: float = 3.0

@export_group("Thresholds (0-1 normalized)")
@export var activation_threshold: float = 0.75    # 75% to enter rage
@export var deactivation_threshold: float = 0.25  # 25% to exit rage

@export_group("Rage Mode Buffs")
@export var damage_mult: float = 1.5
@export var speed_mult: float = 1.3
@export var damage_reduction: float = 0.3

@export_group("Gain Sources")
@export var rage_per_kill: float = 15.0
@export var rage_per_damage_dealt: float = 0.5   # per damage point
@export var rage_per_damage_taken: float = 2.0   # per damage point
@export var rage_per_melee_hit: float = 8.0
@export var rage_on_eat: float = 5.0

var _in_rage: bool = false

func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if _in_rage:
		current_rage = max(0.0, current_rage - decay_per_second * delta)
		if current_rage / max_rage <= deactivation_threshold:
			_exit_rage()
	else:
		# Slow decay when not in rage
		current_rage = max(0.0, current_rage - decay_per_second * 0.5 * delta)
		if current_rage / max_rage >= activation_threshold:
			_enter_rage()
	
	rage_changed.emit(current_rage, max_rage)


func _enter_rage() -> void:
	_in_rage = true
	rage_mode_activated.emit()
	SignalHub.rage_mode_changed.emit(true)


func _exit_rage() -> void:
	_in_rage = false
	rage_mode_deactivated.emit()
	SignalHub.rage_mode_changed.emit(false)


func add_rage(amount: float) -> void:
	current_rage = min(max_rage, current_rage + amount)


func on_kill() -> void:
	add_rage(rage_per_kill)


func on_damage_dealt(amount: float) -> void:
	add_rage(amount * rage_per_damage_dealt)


func on_damage_taken(amount: float) -> void:
	add_rage(amount * rage_per_damage_taken)


func on_melee_hit() -> void:
	add_rage(rage_per_melee_hit)


func on_eat() -> void:
	add_rage(rage_on_eat)


func get_rage_normalized() -> float:
	return current_rage / max_rage


func is_in_rage() -> bool:
	return _in_rage


func get_damage_multiplier() -> float:
	return damage_mult if _in_rage else 1.0


func get_speed_multiplier() -> float:
	return speed_mult if _in_rage else 1.0


func get_damage_reduction() -> float:
	return damage_reduction if _in_rage else 0.0


func debug_line() -> String:
	return "rage: %.1f/%.1f (%s)" % [current_rage, max_rage, "RAGE" if _in_rage else "calm"]