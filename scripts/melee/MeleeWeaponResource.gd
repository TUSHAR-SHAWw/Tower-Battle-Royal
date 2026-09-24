class_name MeleeWeaponResource
extends Resource

## Data-driven melee weapon configuration. Lives in `resources/melee/*.tres`
## so balance can change without touching code (master prompt §47).
##
## Values are PROTOTYPE DEFAULTS — not final balance. Pixel units.

@export_group("Identity")
@export var weapon_name: String = "Unnamed Melee"
@export var weapon_id: StringName = &"unarmed"

@export_group("Damage")
@export var damage: float = 25.0
@export var damage_type: StringName = &"melee"
@export var knockback: float = 300.0
@export var hitstun: float = 0.15

@export_group("Attack Timing")
@export var startup_frames: int = 3       # frames before hitbox activates
@export var active_frames: int = 4        # frames hitbox stays active
@export var recovery_frames: int = 10     # frames after hitbox ends
@export var combo_window_frames: int = 15 # frames to queue next attack
@export var max_combo: int = 3

@export_group("Hitbox Geometry")
@export var arc_degrees: float = 90.0     # swing arc width
@export var range: float = 48.0           # distance from player center
@export var offset_angle: float = 0.0     # degrees offset from aim direction
@export var hitbox_shape: int = 0         # 0 = sector (pie slice), 1 = rectangle

@export_group("Movement")
@export var lunge_speed: float = 600.0    # forward dash during startup
@export var lunge_duration: float = 0.1   # seconds of lunge
@export var root_motion: bool = true      # move player during attack

@export_group("Visuals")
@export var trail_color: Color = Color("#ff8844")
@export var hit_flash_color: Color = Color("#ffff88")
@export var trail_length: float = 1.0

@export_group("Stamina / Resource")
@export var stamina_cost: float = 10.0
@export var rage_gain: float = 5.0

## Returns the list of problems with this configuration (empty means valid).
func validate() -> Array[String]:
	var problems: Array[String] = []
	if weapon_name.is_empty():
		problems.append("weapon_name cannot be empty")
	if damage <= 0.0:
		problems.append("damage must be > 0 (got %.2f)" % damage)
	if not DamageTypes.is_valid(damage_type):
		problems.append("damage_type '%s' is not a registered type" % damage_type)
	if startup_frames < 0:
		problems.append("startup_frames must be >= 0 (got %d)" % startup_frames)
	if active_frames <= 0:
		problems.append("active_frames must be > 0 (got %d)" % active_frames)
	if recovery_frames < 0:
		problems.append("recovery_frames must be >= 0 (got %d)" % recovery_frames)
	if combo_window_frames < 0:
		problems.append("combo_window_frames must be >= 0 (got %d)" % combo_window_frames)
	if max_combo < 1:
		problems.append("max_combo must be >= 1 (got %d)" % max_combo)
	if arc_degrees <= 0.0 or arc_degrees > 360.0:
		problems.append("arc_degrees must be 1-360 (got %.2f)" % arc_degrees)
	if range <= 0.0:
		problems.append("range must be > 0 (got %.2f)" % range)
	if lunge_speed < 0.0:
		problems.append("lunge_speed must be >= 0 (got %.2f)" % lunge_speed)
	if lunge_duration < 0.0:
		problems.append("lunge_duration must be >= 0 (got %.2f)" % lunge_duration)
	if stamina_cost < 0.0:
		problems.append("stamina_cost must be >= 0 (got %.2f)" % stamina_cost)
	return problems


## Total attack duration in frames.
func get_total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


## Total attack duration in seconds (at 60 FPS).
func get_total_duration() -> float:
	return get_total_frames() / 60.0