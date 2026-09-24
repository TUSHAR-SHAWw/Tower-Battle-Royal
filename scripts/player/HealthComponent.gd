class_name HealthComponent
extends Node

## Health for any damageable actor (player now, bots in M7, lootable objects later).
##
## Why an object instead of loose parameters: every listener (HUD, audio, VFX,
## kill credit, future analytics) needs a different slice of the same event, so the
## component emits both the structured `DamageInfo` and the resulting numbers.
##
## This component stays free of `SignalHub`: it emits local signals that mean
## something to whichever actor owns it, and that actor decides what is globally
## relevant (a player dying is, a dummy taking 1 damage is not). See
## docs/ARCHITECTURE.md §7.
##
## Only this component may change health.

signal health_changed(current: float, maximum: float)
signal damaged(info: DamageInfo, applied: float)
signal healed(amount: float)
## Emitted once per death, with the damaging event (empty info for scripted deaths).
signal died(info: DamageInfo)

@export var max_health: float = 100.0
## Reachable through the cheat console and spawn protection later.
@export var invulnerable: bool = false

## Incoming damage scale. M4's DefenseComponent will own this value (melee
## gun-damage reduction); damage types that bypass defense ignore it.
@export var damage_multiplier: float = 1.0

var current_health: float = 100.0


func _ready() -> void:
	if max_health <= 0.0:
		push_error("HealthComponent: max_health must be > 0 (got %.2f)." % max_health)
		max_health = maxf(max_health, 1.0)
	if current_health <= 0.0 or current_health > max_health:
		current_health = max_health


# ------------------------------------------------------------------------ public

## Applies damage and returns how much health was actually lost (0 when the hit
## was ignored: already dead, invulnerable, or zero damage).
func apply_damage(info: DamageInfo) -> float:
	if info == null:
		push_error("HealthComponent.apply_damage received null DamageInfo.")
		return 0.0
	if is_dead() or invulnerable:
		return 0.0

	var scaled := info.amount
	if not DamageTypes.bypasses_defense(info.type):
		scaled *= maxf(damage_multiplier, 0.0)
	var applied := minf(maxf(scaled, 0.0), current_health)
	if applied <= 0.0:
		return 0.0

	current_health -= applied
	damaged.emit(info, applied)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit(info)
	return applied


## Restores health and returns how much was actually restored.
func heal(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var restored := minf(amount, max_health - current_health)
	if restored <= 0.0:
		return 0.0
	current_health += restored
	healed.emit(restored)
	health_changed.emit(current_health, max_health)
	return restored


## Kills the actor outright (floor deletion, match end, starvation in M6).
func kill(killer: Node = null) -> void:
	if is_dead():
		return
	var info := DamageInfo.create(current_health, DamageTypes.UNAVOIDABLE, killer)
	current_health = 0.0
	damaged.emit(info, info.amount)
	health_changed.emit(current_health, max_health)
	died.emit(info)


## Brings a dead actor back at full health (respawn / "revive" cheat / restart).
func revive() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func set_max_health(value: float, keep_ratio: bool = true) -> void:
	var ratio := health_ratio()
	max_health = maxf(value, 1.0)
	current_health = clampf(max_health * ratio if keep_ratio else current_health, 0.0, max_health)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0.0


func health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func debug_line() -> String:
	return "%.0f/%.0f hp" % [current_health, max_health]
