class_name DamageInfo
extends RefCounted

## One damage event, passed *by reference* from attacker to defender.
##
## Why an object instead of parameters: every listener (health, HUD, audio, VFX,
## killer-credit, future analytics) needs a different slice of the same event.
## Passing loose floats means editing five call sites every time a weapon gains a
## new property (master prompt §14).
##
## Damage is created through the static builder so the intent reads as a sentence:
##     DamageInfo.create(12.0, DamageTypes.BULLET, shooter, muzzle)
##         .with_knockback(aim_dir, 180.0)
##         .with_critical(true)
##
## Element ids, status effects and other post-M12 payloads are added by the
## milestone that introduces their data classes — no speculative fields here.

var amount: float = 0.0
var type: StringName = DamageTypes.BULLET
## Element id (&"fire", &"ice"...) once elemental weapons exist (M12); empty = physical.
var element: StringName = &""
## The node that physically caused the hit (projectile, melee hitbox...).
var source: Node = null
## The actor credited with the kill — the shooter/swinger, not the projectile.
var instigator: Node = null
## World-space point of contact (impact VFX, hit markers).
var hit_position: Vector2 = Vector2.ZERO
## Impulse direction * magnitude in pixels per second.
var knockback: Vector2 = Vector2.ZERO
var is_critical: bool = false


static func create(
	p_amount: float,
	p_type: StringName = DamageTypes.BULLET,
	p_instigator: Node = null,
	p_source: Node = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = maxf(p_amount, 0.0)
	info.type = p_type
	info.instigator = p_instigator
	info.source = p_source
	return info


# ------------------------------------------------------------------ fluent setup

func with_element(element_id: StringName) -> DamageInfo:
	element = element_id
	return self


func with_hit_position(position: Vector2) -> DamageInfo:
	hit_position = position
	return self


func with_critical(critical: bool = true) -> DamageInfo:
	is_critical = critical
	return self


## Sets a knockback impulse. `direction` is normalised, `force` is the impulse
## magnitude in pixels per second (0 disables knockback).
func with_knockback(direction: Vector2, force: float) -> DamageInfo:
	if force <= 0.0 or direction.is_zero_approx():
		knockback = Vector2.ZERO
	else:
		knockback = direction.normalized() * force
	return self


func with_amount(new_amount: float) -> DamageInfo:
	amount = maxf(new_amount, 0.0)
	return self


# ------------------------------------------------------------------- inspection

## True when `node` is either the instigator or the direct source.
func is_from(node: Node) -> bool:
	return node != null and (node == instigator or node == source)


func has_knockback() -> bool:
	return not knockback.is_zero_approx()


func _to_string() -> String:
	return "DamageInfo(amount=%.2f type=%s element=%s crit=%s kb=%.1f instigator=%s source=%s)" % [
		amount,
		type,
		element if not element.is_empty() else &"physical",
		is_critical,
		knockback.length(),
		instigator.name if instigator != null else &"none",
		source.name if source != null else &"none",
	]
