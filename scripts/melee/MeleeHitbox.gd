class_name MeleeHitbox
extends Area2D

## Sector-shaped hitbox for melee attacks.
## Activated/deactivated by MeleeComponent.

signal hit(target: Node, position: Vector2, normal: Vector2)

var _weapon: MeleeWeaponResource = null
var _owner: Node = null
var _combo_index: int = 0
var _active: bool = false
var _hit_targets: Array[int] = []  # instance IDs already hit this swing

@export var debug_draw: bool = true


func _ready() -> void:
	monitoring = false
	monitorable = false
	
	# Collision layers: melee hits enemies/players
	collision_layer = 0
	collision_mask = PhysicsLayers.ENEMY | PhysicsLayers.PLAYER | PhysicsLayers.ENVIRONMENT
	
	area_entered.connect(_on_area_entered)


func activate(weapon: MeleeWeaponResource, owner: Node, combo_index: int) -> void:
	_weapon = weapon
	_owner = owner
	_combo_index = combo_index
	_active = true
	_hit_targets.clear()
	
	monitoring = true
	_update_shape()


func deactivate() -> void:
	_active = false
	monitoring = false
	_weapon = null
	_owner = null
	queue_redraw()


func _update_shape() -> void:
	if _weapon == null:
		return
	
	# Clear existing collision shapes
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	# Create sector shape (pie slice)
	var shape := CollisionShape2D.new()
	var sector := CircleShape2D.new()
	sector.radius = _weapon.range
	shape.shape = sector
	add_child(shape)
	shape.owner = self
	
	# Note: Godot 4 doesn't have built-in sector shape.
	# For now we use a circle and filter by angle in _on_area_entered.
	# A proper sector would need a custom ConcavePolygonShape2D.


func _on_area_entered(area: Area2D) -> void:
	if not _active or _weapon == null or _owner == null:
		return
	
	var target_id := area.get_instance_id()
	if _hit_targets.has(target_id):
		return
	
	# Check if target is in the attack arc
	var to_target: Vector2 = (area.global_position - _owner.global_position).normalized()
	var attack_dir: Vector2 = _owner.get_aim_direction() if _owner.has_method("get_aim_direction") else Vector2.RIGHT
	attack_dir = attack_dir.rotated(deg_to_rad(_weapon.offset_angle))
	
	var angle_to_target: float = attack_dir.angle_to(to_target)
	var half_arc: float = deg_to_rad(_weapon.arc_degrees * 0.5)
	
	if abs(angle_to_target) <= half_arc:
		# Check distance
		var dist: float = _owner.global_position.distance_to(area.global_position)
		if dist <= _weapon.range:
			_hit_targets.append(target_id)
			var hit_pos: Vector2 = area.global_position
			var hit_normal: Vector2 = to_target
			hit.emit(area, hit_pos, hit_normal)


func _draw() -> void:
	if not debug_draw or not _active or _weapon == null:
		return
	
	# Draw sector for debugging
	var attack_dir: Vector2 = _owner.get_aim_direction() if _owner.has_method("get_aim_direction") else Vector2.RIGHT
	attack_dir = attack_dir.rotated(deg_to_rad(_weapon.offset_angle))
	
	var half_arc: float = deg_to_rad(_weapon.arc_degrees * 0.5)
	var color: Color = _weapon.trail_color
	
	# Draw arc lines
	var start_angle: float = attack_dir.angle() - half_arc
	var end_angle: float = attack_dir.angle() + half_arc
	
	var center: Vector2 = Vector2.ZERO
	var radius: float = _weapon.range
	
	# Arc outline
	var points: Array[Vector2] = [center]
	for i in range(16):
		var t: float = float(i) / 15.0
		var angle: float = start_angle + (end_angle - start_angle) * t
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	points.append(center)
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, 2.0)
	
	# Center line
	draw_line(center, attack_dir * radius, color * Color(1, 1, 1, 0.5), 1.0)