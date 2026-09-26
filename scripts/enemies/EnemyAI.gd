class_name EnemyAI
extends Node

## Enemy AI with state machine: idle -> patrol -> chase -> attack -> flee.

signal state_changed(new_state: StringName)
signal attacked(target: Node)
signal died(killer: Node)

@export var enemy_data: EnemyResource

var _state: StringName = &"idle"
var _target: Node = null
var _owner: CharacterBody2D = null
var _movement: MovementComponent = null
var _health: HealthComponent = null

var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_timer: float = 0.0
var _attack_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO

enum State { IDLE, PATROL, CHASE, ATTACK, FLEE, DEAD }

func _ready() -> void:
	_owner = get_parent() as CharacterBody2D
	_movement = _owner.get_node_or_null("MovementComponent")
	_health = _owner.get_node_or_null("HealthComponent")
	
	if _health != null:
		_health.died.connect(_on_died)
	
	_pick_patrol_target()


func _physics_process(delta: float) -> void:
	if _state == &"dead" or enemy_data == null:
		return
	
	_update_target()
	
	match _state:
		&"idle": _handle_idle(delta)
		&"patrol": _handle_patrol(delta)
		&"chase": _handle_chase(delta)
		&"attack": _handle_attack(delta)
		&"flee": _handle_flee(delta)
	
	_check_stuck(delta)


func _update_target() -> void:
	var player := _find_player()
	if player != null:
		var dist := _owner.global_position.distance_to(player.global_position)
		if dist <= enemy_data.aggro_range:
			_target = player
		elif _target != null and dist > enemy_data.deaggro_range:
			_target = null
	else:
		_target = null


func _find_player() -> Node:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene.get_node_or_null("PlayerInstance") or tree.current_scene.get_node_or_null("Player")
	return null


func _handle_idle(delta: float) -> void:
	# Transition to patrol after brief idle
	_patrol_timer += delta
	if _patrol_timer >= 2.0:
		_set_state(&"patrol")
		_patrol_timer = 0.0
		_pick_patrol_target()


func _handle_patrol(delta: float) -> void:
	if _movement == null:
		return
	
	if _target != null:
		_set_state(&"chase")
		return
	
	var dist := _owner.global_position.distance_to(_patrol_target)
	if dist < 20.0:
		_set_state(&"idle")
		return
	
	var dir := (_patrol_target - _owner.global_position).normalized()
	_movement.move(dir)
	
	# Random chance to switch to idle
	if randf() < 0.005:
		_set_state(&"idle")


func _handle_chase(delta: float) -> void:
	if _target == null or _movement == null:
		_set_state(&"patrol")
		return
	
	var dist := _owner.global_position.distance_to(_target.global_position)
	
	if dist <= enemy_data.attack_range:
		_set_state(&"attack")
		return
	
	if dist > enemy_data.deaggro_range:
		_target = null
		_set_state(&"patrol")
		return
	
	var dir := (_target.global_position - _owner.global_position).normalized()
	_movement.move(dir)
	
	# Check if stuck
	if _owner.global_position.distance_to(_last_position) < 5.0:
		_stuck_timer += delta
		if _stuck_timer > 3.0:
			_pick_patrol_target()
			_set_state(&"patrol")
	else:
		_stuck_timer = 0.0
	
	_last_position = _owner.global_position


func _handle_attack(delta: float) -> void:
	if _target == null:
		_set_state(&"chase")
		return
	
	var dist := _owner.global_position.distance_to(_target.global_position)
	if dist > enemy_data.attack_range * 1.2:
		_set_state(&"chase")
		return
	
	_attack_timer += delta
	if _attack_timer >= enemy_data.attack_cooldown:
		_perform_attack()
		_attack_timer = 0.0


func _perform_attack() -> void:
	if _target == null:
		return
	
	if _target.has_method("take_damage"):
		var info := DamageInfo.create(enemy_data.damage, &enemy_data.damage_type, _owner, _owner)
		info.knockback = enemy_data.knockback
		info.position = _owner.global_position
		info.direction = (_target.global_position - _owner.global_position).normalized()
		_target.take_damage(info)
	
	attacked.emit(_target)
	SignalHub.enemy_attacked.emit(_owner, _target)


func _handle_flee(delta: float) -> void:
	if _target == null or _movement == null:
		_set_state(&"patrol")
		return
	
	# Move away from target
	var dir := (_owner.global_position - _target.global_position).normalized()
	_movement.move(dir)
	
	var dist := _owner.global_position.distance_to(_target.global_position)
	if dist > enemy_data.deaggro_range:
		_target = null
		_set_state(&"patrol")


func _check_stuck(delta: float) -> void:
	# Already handled in chase


func _pick_patrol_target() -> void:
	var center := _owner.global_position
	var angle := randf() * TAU
	var dist := randf_range(50.0, enemy_data.patrol_radius)
	_patrol_target = center + Vector2(cos(angle), sin(angle)) * dist


func _set_state(new_state: StringName) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)
	
	match new_state:
		&"idle": _patrol_timer = 0.0
		&"patrol": _pick_patrol_target()
		&"chase": _attack_timer = 0.0
		&"attack": _attack_timer = 0.0
		&"flee": pass
		&"dead": pass


func _on_died(info: DamageInfo) -> void:
	_set_state(&"dead")
	died.emit(info.source)
	SignalHub.enemy_died.emit(_owner, info.source)


func get_state() -> StringName:
	return _state


func force_target(target: Node) -> void:
	_target = target
	if _state != &"dead":
		_set_state(&"chase")