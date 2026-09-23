class_name DamageTypes
extends RefCounted

## Canonical damage-type ids shared by weapons, melee, status effects and the HUD.
##
## StringNames instead of an enum so a type can be stored inside Resources
## (WeaponData.damage_type) and serialised in .tres files without renumbering
## risk. Add new ids here — never as loose strings at call sites.

const BULLET := &"bullet"          ## Guns.
const MELEE := &"melee"            ## Melee weapons (reduced by some defenses).
const EXPLOSION := &"explosion"    ## Area damage.
const FALL := &"fall"              ## Falling through the central shaft (M7+).
const STARVATION := &"starvation"  ## Hunger at zero (M6).
const STATUS := &"status"          ## Burn/poison/bleed ticks (M12).
const ENVIRONMENT := &"environment" ## Hazards: collapsing floor, spikes (M8).
const UNAVOIDABLE := &"unavoidable" ## Ignores every defense multiplier.

static var _all: Array[StringName] = [BULLET, MELEE, EXPLOSION, FALL, STARVATION, STATUS, ENVIRONMENT, UNAVOIDABLE]


static func all() -> Array[StringName]:
	return _all.duplicate()


static func is_valid(id: StringName) -> bool:
	return _all.has(id)


## True for damage that ignores defensive multipliers (see DefenseComponent).
static func bypasses_defense(id: StringName) -> bool:
	return id == UNAVOIDABLE or id == STARVATION
