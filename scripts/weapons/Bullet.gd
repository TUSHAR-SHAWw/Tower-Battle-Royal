class_name Bullet
extends RigidBody2D

## Pooled projectile. Configured by GunComponent on spawn.
## Uses RigidBody2D for physics-based movement + collision.

@export var damage: float = 10.0
@export var damage_type: StringName = &"bullet"
@export var knockback: float = 0.0
@export var pierce_remaining: int = 0
@export var lifetime: float = 2.0
@export var gravity: float = 0.0

var _visual: Node2D = null
var _trail: Array[Vector2] = []
var _max_trail_points: int = 8
var _owner_id: int = 0
var _hit_ids: Array[int] = []

func _ready() -> void:
	# Physics setup
	gravity_scale = 0.0
	angular_damp = 1.0
	linear_damp = 0.0
	
	# Collision layers: bullet layer, hit player/enemy/hazard layers
	collision_layer = PhysicsLayers.BULLET
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.ENEMY | PhysicsLayers.ENVIRONMENT
	
	# Continuous collision detection for fast bullets
	continuous_cd = true
	
	# Visual
	_visual = Node2D.new()
	add_child(_visual)
	
	# Connect signals
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_despawn()
		return
	
	# Apply gravity if set
	if gravity != 0.0:
		linear_velocity += Vector2(0, gravity) * delta
	
	# Update trail
	_update_trail()

func _update_trail() -> void:
	_trail.append(global_position)
	if _trail.size() > _max_trail_points:
		_trail.remove_at(0)
	
	if _visual != null:
		_visual.queue_redraw()

func _draw() -> void:
	if _visual == null:
		return
	
	# Draw trail
	if _trail.size() >= 2:
		var trail_color := Color(1.0, 1.0, 0.5, 0.6)
		for i in range(_trail.size() - 1):
			var alpha := float(i + 1) / _trail.size() * 0.6
			draw_line(_trail[i], _trail[i + 1], trail_color * Color(1, 1, 1, alpha), 2.0)
	
	# Draw bullet body (simple circle)
	var bullet_color := Color(1.0, 1.0, 0.5, 1.0)
	draw_circle(Vector2.ZERO, 3.0, bullet_color)

func _on_body_entered(body: Node2D) -> void:
	# Don't hit self
	if body.get_instance_id() == _owner_id:
		return
	
	# Don't hit same target twice (for piercing)
	if _hit_ids.has(body.get_instance_id()):
		return
	
	# Apply damage
	if body.has_method("take_damage"):
		var info := DamageInfo.new()
		info.damage = damage
		info.damage_type = damage_type
		info.knockback = knockback
		info.source = self
		info.position = global_position
		info.direction = linear_velocity.normalized()
		body.take_damage(info)
	
	_hit_ids.append(body.get_instance_id())
	
	# Handle piercing
	pierce_remaining -= 1
	if pierce_remaining < 0:
		_despawn()
	else:
		# Small visual feedback on hit
		_visual.modulate = Color(1, 0.3, 0.3, 1)
		call_deferred("_reset_visual")


func _reset_visual() -> void:
	if _visual != null:
		_visual.modulate = Color(1, 1, 1, 1)


func configure(damage: float, damage_type: StringName, knockback: float, pierce: int, lifetime: float, gravity: float, owner_id: int, bullet_color: Color = Color(1,1,0.5), bullet_size: float = 4.0) -> void:
	self.damage = damage
	self.damage_type = damage_type
	self.knockback = knockback
	self.pierce_remaining = pierce
	self.lifetime = lifetime
	self.gravity = gravity
	self._owner_id = owner_id
	
	# Visual config stored for _draw
	# (would need a way to pass this to _draw, simplified for now)


func _despawn() -> void:
	# Return to pool via ObjectPool
	if is_inside_tree():
		ObjectPool.release(self)


## Static factory for pool prewarming
static func create_bullet() -> Bullet:
	var bullet := Bullet.new()
	bullet.freeze = true
	return bullet