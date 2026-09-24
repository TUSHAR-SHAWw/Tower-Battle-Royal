class_name MeleeComponent
extends Node

## Handles melee attacks: combos, lunge, hitbox activation.
## Designed to be attached to Player and driven by InputIntent.

@export var weapon: MeleeWeaponResource

## Emitted when attack starts (combo_index, total_frames)
signal attack_started(combo_index: int, total_frames: int)

## Emitted when hitbox becomes active/inactive
signal hitbox_activated()
signal hitbox_deactivated()

## Emitted when attack hits something (target, damage_info)
signal attack_hit(target: Node, info: DamageInfo)

## Emitted when combo window opens/closes
signal combo_window_open()
signal combo_window_close()

## Emitted when attack cannot start (cooldown, no stamina, etc.)
signal attack_blocked(reason: StringName)

var _current_combo: int = 0
var _frame_counter: int = 0
var _state: StringName = &"idle"  # idle, startup, active, recovery, combo_window
var _lunge_velocity: Vector2 = Vector2.ZERO
var _owner: Node = null
var _hitbox: Node = null
var _queued_next_attack: bool = false

func _ready() -> void:
	_owner = get_parent()
	_validate_weapon()
	
	# Find or create hitbox
	_hitbox = get_node_or_null("MeleeHitbox")
	if _hitbox == null:
		# Hitbox will be created by the scene
		pass

func _validate_weapon() -> void:
	if weapon == null:
		push_error("MeleeComponent: weapon resource not assigned!")
		return
	var problems := weapon.validate()
	if problems.size() > 0:
		push_error("MeleeComponent: invalid weapon '%s': %s" % [weapon.weapon_name, problems])

func _physics_process(delta: float) -> void:
	if weapon == null:
		return
	
	match _state:
		&"startup":
			_handle_startup(delta)
		&"active":
			_handle_active(delta)
		&"recovery":
			_handle_recovery(delta)
		&"combo_window":
			_handle_combo_window(delta)

func _handle_startup(delta: float) -> void:
	_frame_counter += 1
	
	# Apply lunge movement
	if weapon.root_motion and _lunge_velocity.length() > 0.0:
		if _owner is CharacterBody2D:
			_owner.velocity = _lunge_velocity
	
	if _frame_counter >= weapon.startup_frames:
		
		# Activate hitbox
		_activate_hitbox()
		_state = &"active"
		_frame_counter = 0
		hitbox_activated.emit()

func _handle_active(delta: float) -> void:
	_frame_counter += 1
	
	# Still apply lunge if in lunge duration
	if weapon.root_motion and _frame_counter <= weapon.lunge_duration * 60:
		if _owner is CharacterBody2D:
			_owner.velocity = _lunge_velocity
	
	if _frame_counter >= weapon.active_frames:
		_deactivate_hitbox()
		_state = &"recovery"
		_frame_counter = 0
		hitbox_deactivated.emit()

func _handle_recovery(delta: float) -> void:
	_frame_counter += 1
	
	if _frame_counter >= weapon.recovery_frames:
		# Enter combo window
		_state = &"combo_window"
		_frame_counter = 0
		combo_window_open.emit()

func _handle_combo_window(delta: float) -> void:
	_frame_counter += 1
	
	if _queued_next_attack:
		# Start next combo attack
		_queued_next_attack = false
		_current_combo = (_current_combo + 1) % weapon.max_combo
		_start_attack()
		return
	
	if _frame_counter >= weapon.combo_window_frames:
		# Combo window closed, reset
		combo_window_close.emit()
		_current_combo = 0
		_state = &"idle"
		_frame_counter = 0


## Try to start an attack. Returns true if started.
func try_attack(aim_direction: Vector2) -> bool:
	if weapon == null:
		attack_blocked.emit(&"no_weapon")
		return false
	
	if _state == &"idle":
		_current_combo = 0
		_start_attack(aim_direction)
		return true
	
	if _state == &"combo_window":
		# Queue next attack
		if _current_combo < weapon.max_combo - 1:
			_queued_next_attack = true
			return true
	
	attack_blocked.emit(&"busy")
	return false


func _start_attack(aim_direction: Vector2 = Vector2.RIGHT) -> void:
	_state = &"startup"
	_frame_counter = 0
	
	# Calculate lunge velocity
	if weapon.root_motion and weapon.lunge_speed > 0.0:
		var lunge_dir := aim_direction.rotated(deg_to_rad(weapon.offset_angle))
		_lunge_velocity = lunge_dir * weapon.lunge_speed
	else:
		_lunge_velocity = Vector2.ZERO
	
	attack_started.emit(_current_combo, weapon.get_total_frames())
	SignalHub.melee_attack_started.emit(weapon.weapon_id, _current_combo)


func _activate_hitbox() -> void:
	if _hitbox != null and _hitbox.has_method("activate"):
		_hitbox.activate(weapon, _owner, _current_combo)


func _deactivate_hitbox() -> void:
	if _hitbox != null and _hitbox.has_method("deactivate"):
		_hitbox.deactivate()


## Called by hitbox when it hits a target
func _on_hitbox_hit(target: Node, hit_position: Vector2, hit_normal: Vector2) -> void:
	var info := DamageInfo.create(weapon.damage, weapon.damage_type, _owner, _owner)
	info.with_hit_position(hit_position)
	info.with_knockback(hit_normal, weapon.knockback)
	
	if target.has_method("take_damage"):
		target.take_damage(info)
	
	attack_hit.emit(target, info)
	SignalHub.melee_attack_hit.emit(weapon.weapon_id, target, info)


## Getters
func get_state() -> StringName:
	return _state

func get_combo_index() -> int:
	return _current_combo

func get_frame_progress() -> float:
	var total := weapon.get_total_frames() if weapon != null else 1
	return clamp(_frame_counter / total, 0.0, 1.0)

func can_attack() -> bool:
	return weapon != null and (_state == &"idle" or _state == &"combo_window")

func is_in_combo_window() -> bool:
	return _state == &"combo_window"