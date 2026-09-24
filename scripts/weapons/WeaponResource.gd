class_name WeaponResource
extends Resource

## Data-driven weapon configuration. Lives in `resources/weapons/*.tres`
## so balance can change without touching code (master prompt §47).
##
## Values are PROTOTYPE DEFAULTS — not final balance. Pixel units.

@export_group("Identity")
@export var weapon_name: String = "Unnamed Weapon"
@export var weapon_id: StringName = &"unarmed"

@export_group("Damage")
@export var damage: float = 10.0
@export var damage_type: StringName = &"bullet"
@export var knockback: float = 0.0

@export_group("Fire Rate")
@export var fire_rate_rpm: float = 600.0
@export var burst_count: int = 1
@export var burst_delay: float = 0.06

@export_group("Ammo")
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 1.8
@export var infinite_ammo: bool = false

@export_group("Ballistics")
@export var bullet_speed: float = 800.0
@export var bullet_lifetime: float = 2.0
@export var spread_degrees: float = 0.5
@export var bullet_gravity: float = 0.0
@export var pierce_count: int = 0

@export_group("Visuals")
@export var muzzle_flash_color: Color = Color("#ffaa00")
@export var bullet_color: Color = Color("#ffff88")
@export var bullet_size: float = 4.0
@export var tracer_length: float = 16.0

@export_group("Recoil / Feel")
@export var recoil_impulse: float = 120.0
@export var recoil_recovery: float = 12.0
@export var screen_shake: float = 2.0

## Returns the list of problems with this configuration (empty means valid).
func validate() -> Array[String]:
	var problems: Array[String] = []
	if weapon_name.is_empty():
		problems.append("weapon_name cannot be empty")
	if damage <= 0.0:
		problems.append("damage must be > 0 (got %.2f)" % damage)
	if not DamageTypes.is_valid(damage_type):
		problems.append("damage_type '%s' is not a registered type" % damage_type)
	if fire_rate_rpm <= 0.0:
		problems.append("fire_rate_rpm must be > 0 (got %.2f)" % fire_rate_rpm)
	if burst_count < 1:
		problems.append("burst_count must be >= 1 (got %d)" % burst_count)
	if burst_delay < 0.0:
		problems.append("burst_delay must be >= 0 (got %.2f)" % burst_delay)
	if magazine_size <= 0:
		problems.append("magazine_size must be > 0 (got %d)" % magazine_size)
	if reserve_ammo < 0:
		problems.append("reserve_ammo must be >= 0 (got %d)" % reserve_ammo)
	if reload_time <= 0.0:
		problems.append("reload_time must be > 0 (got %.2f)" % reload_time)
	if bullet_speed <= 0.0:
		problems.append("bullet_speed must be > 0 (got %.2f)" % bullet_speed)
	if bullet_lifetime <= 0.0:
		problems.append("bullet_lifetime must be > 0 (got %.2f)" % bullet_lifetime)
	if spread_degrees < 0.0:
		problems.append("spread_degrees must be >= 0 (got %.2f)" % spread_degrees)
	if pierce_count < 0:
		problems.append("pierce_count must be >= 0 (got %d)" % pierce_count)
	return problems


## Fire interval in seconds (derived from RPM).
func get_fire_interval() -> float:
	return 60.0 / fire_rate_rpm