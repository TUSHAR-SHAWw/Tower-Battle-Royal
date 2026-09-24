class_name GunComponent
extends Node

## Handles weapon firing, reloading, and ammo management.
## Designed to be attached to Player and driven by InputIntent.

@export var weapon: WeaponResource

## Emitted when a shot is fired (position, direction, weapon_id).
signal shot_fired(global_position: Vector2, direction: Vector2, weapon_id: StringName)

## Emitted when reload starts/ends.
signal reload_started()
signal reload_finished()

## Emitted when ammo changes (current_mag, reserve).
signal ammo_changed(current_mag: int, reserve: int)

## Emitted when weapon cannot fire (empty, reloading, cooldown).
signal fire_blocked(reason: StringName)

var _current_mag: int = 0
var _reserve_ammo: int = 0
var _fire_cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0
var _burst_shots_remaining: int = 0
var _burst_timer: float = 0.0
var _burst_aim_direction: Vector2 = Vector2.RIGHT
var _burst_global_position: Vector2 = Vector2.ZERO
var _owner: Node = null

func _ready() -> void:
	_owner = get_parent()
	_validate_weapon()
	_reset_ammo()
	ammo_changed.emit(_current_mag, _reserve_ammo)

func _validate_weapon() -> void:
	if weapon == null:
		push_error("GunComponent: weapon resource not assigned!")
		return
	var problems := weapon.validate()
	if problems.size() > 0:
		push_error("GunComponent: invalid weapon '%s': %s" % [weapon.weapon_name, problems])

func _reset_ammo() -> void:
	if weapon == null:
		return
	_current_mag = weapon.magazine_size
	_reserve_ammo = weapon.reserve_ammo if not weapon.infinite_ammo else -1

func _physics_process(delta: float) -> void:
	if weapon == null:
		return
	
	# Handle burst fire timing
	if _burst_shots_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_shots_remaining -= 1
			if _burst_shots_remaining > 0:
				_burst_timer = weapon.burst_delay
				_fire_shot(_burst_aim_direction, _burst_global_position)
			else:
				_fire_cooldown = weapon.get_fire_interval()
	
	# Handle fire cooldown
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	
	# Handle reload
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()


## Try to fire the weapon. Returns true if a shot was fired.
func try_fire(aim_direction: Vector2, global_position: Vector2) -> bool:
	if weapon == null:
		fire_blocked.emit(&"no_weapon")
		return false
	
	if _reloading:
		fire_blocked.emit(&"reloading")
		return false
	
	if _fire_cooldown > 0.0:
		fire_blocked.emit(&"cooldown")
		return false
	
	if _current_mag <= 0:
		if _reserve_ammo > 0 or weapon.infinite_ammo:
			start_reload()
		fire_blocked.emit(&"empty")
		return false
	
	# Start burst
	_burst_shots_remaining = weapon.burst_count
	_burst_timer = 0.0
	_burst_aim_direction = aim_direction
	_burst_global_position = global_position
	_fire_shot(aim_direction, global_position)
	_fire_cooldown = weapon.get_fire_interval()
	return true


func _fire_shot(aim_direction: Vector2, global_position: Vector2) -> void:
	_current_mag -= 1
	if not weapon.infinite_ammo:
		_reserve_ammo = max(0, _reserve_ammo)
	ammo_changed.emit(_current_mag, _reserve_ammo)
	
	# Apply spread
	var spread_rad := deg_to_rad(weapon.spread_degrees)
	var spread_angle := randf_range(-spread_rad, spread_rad)
	var shot_dir := aim_direction.rotated(spread_angle)
	
	shot_fired.emit(global_position, shot_dir, weapon.weapon_id)
	
	# SignalHub integration for other systems (HUD, etc.)
	SignalHub.weapon_fired.emit(weapon.weapon_id, global_position, shot_dir)


## Start reloading if possible.
func start_reload() -> bool:
	if weapon == null:
		return false
	if _reloading:
		return false
	if _current_mag >= weapon.magazine_size:
		return false
	if _reserve_ammo <= 0 and not weapon.infinite_ammo:
		return false
	
	_reloading = true
	_reload_timer = weapon.reload_time
	reload_started.emit()
	return true


func _finish_reload() -> void:
	_reloading = false
	
	if weapon.infinite_ammo:
		_current_mag = weapon.magazine_size
	else:
		var needed: int = weapon.magazine_size - _current_mag
		var taken: int = min(needed, _reserve_ammo)
		_current_mag += taken
		_reserve_ammo -= taken
	
	ammo_changed.emit(_current_mag, _reserve_ammo)
	reload_finished.emit()


## Force cancel reload (e.g. on weapon swap).
func cancel_reload() -> void:
	if _reloading:
		_reloading = false
		_reload_timer = 0.0


## Getters
func get_current_mag() -> int:
	return _current_mag

func get_reserve_ammo() -> int:
	return _reserve_ammo

func is_reloading() -> bool:
	return _reloading

func get_reload_progress() -> float:
	if not _reloading or weapon == null:
		return 1.0
	return 1.0 - (_reload_timer / weapon.reload_time)

func get_fire_cooldown_progress() -> float:
	if weapon == null:
		return 1.0
	return clamp(1.0 - (_fire_cooldown / weapon.get_fire_interval()), 0.0, 1.0)

func can_fire() -> bool:
	return weapon != null and not _reloading and _fire_cooldown <= 0.0 and _current_mag > 0