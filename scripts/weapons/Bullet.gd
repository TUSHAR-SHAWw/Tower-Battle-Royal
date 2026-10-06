class_name Bullet
extends RigidBody2D

## Pooled projectile. Configured by ProjectileSpawner on spawn.
## Uses RigidBody2D for physics-based movement + collision.

@export var damage: float = 10.0
@export var damage_type: StringName = DamageTypes.BULLET
@export var knockback: float = 0.0
@export var pierce_remaining: int = 0
@export var lifetime: float = 2.0
@export var gravity: float = 0.0
## Element id carried into the DamageInfo (empty = physical).
@export var element: StringName = &""

var _visual: Node2D = null
var _trail: Array[Vector2] = []
var _max_trail_points: int = 8
## Instance id of the actor that fired this shot; it must not hit its owner.
var _owner_id: int = 0
var _instigator: Node = null
var _hit_ids: Array[int] = []
var _hit_detector: Area2D = null
var _bullet_color: Color = Color(1.0, 1.0, 0.5, 1.0)
var _bullet_size: float = 3.0

func _ready() -> void:
	# Physics setup
	gravity_scale = 0.0
	angular_damp = 1.0
	linear_damp = 0.0
	collision_layer = PhysicsLayers.PROJECTILE
	collision_mask = PhysicsLayers.WORLD
	
	# A projectile can only ever touch *hurtboxes* and world geometry. Masking the
	# actor body layers instead meant bullets passed straight through everyone.
	_hit_detector = get_node_or_null("HitDetector") as Area2D
	if _hit_detector == null:
		push_error("Bullet: missing HitDetector Area2D.")
		return
	_hit_detector.collision_layer = 0
	_hit_detector.collision_mask = PhysicsLayers.PLAYER_HURTBOX | PhysicsLayers.ENEMY_HURTBOX
	_hit_detector.monitoring = true
	_hit_detector.monitorable = false

	# Continuous collision detection for fast bullets
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	
	# Visual
	_visual = Node2D.new()
	add_child(_visual)
	
	# Connect signals. Hurtboxes are Area2Ds, so area_entered is the one that
	# actually fires for actors; body_entered is kept for world geometry.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not _hit_detector.area_entered.is_connected(_on_area_entered):
		_hit_detector.area_entered.connect(_on_area_entered)

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

## World geometry is a body, so a body hit always stops the shot.
func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	# Only world geometry arrives here now that the mask excludes actor layers.
	_despawn()


## Actors are hit through their hurtbox Area2D.
func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	var target := _resolve_target(area)
	if target == null:
		return
	if not _try_hit(target):
		return
	# World geometry is the only thing that stops a shot outright; an actor only
	# stops it when the pierce budget runs out.
	if pierce_remaining < 0:
		_despawn()


## Applies damage to `target` once per shot. Returns true when the hit landed.
func _try_hit(target: Node) -> bool:
	var target_id := target.get_instance_id()
	if target_id == _owner_id:
		return false
	if _hit_ids.has(target_id):
		return false
	if not target.has_method(&"take_damage"):
		return false

	_hit_ids.append(target_id)

	# DamageInfo.create(...) is the only supported way to build one: assigning to
	# `info.damage` / `info.damage_type` / `info.position` silently created fields
	# on a RefCounted, so every bullet dealt 0 damage.
	var info := DamageInfo.create(damage, damage_type, _instigator, self)
	info.with_hit_position(global_position)
	if not element.is_empty():
		info.with_element(element)
	var dir := linear_velocity.normalized()
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	info.with_knockback(dir, knockback)
	target.take_damage(info)

	pierce_remaining -= 1
	if _visual != null and pierce_remaining >= 0:
		# Small visual feedback when the shot survives the hit.
		_visual.modulate = Color(1, 0.3, 0.3, 1)
		call_deferred(&"_reset_visual")
	return true


## Walks up from a hurtbox to the actor that owns it (Player/Hurtbox, Enemy/Hurtbox).
func _resolve_target(area: Area2D) -> Node:
	var node: Node = area.get_parent()
	while node != null:
		if node.has_method(&"take_damage"):
			return node
		node = node.get_parent()
	return null


func _reset_visual() -> void:
	if _visual != null:
		_visual.modulate = Color(1, 1, 1, 1)


## Configures a freshly acquired (or pooled) bullet before it is launched.
##
## `instigator` is the actor credited with the kill — the shooter, not the bullet.
## Called by ProjectileSpawner; keep every field reset here because pooled bullets
## are reused and would otherwise carry state between shots.
func configure(
	p_damage: float,
	p_damage_type: StringName,
	p_knockback: float,
	p_pierce: int,
	p_lifetime: float,
	p_gravity: float,
	p_instigator: Node,
	p_element: StringName = &"",
	p_color: Color = Color(1.0, 1.0, 0.5, 1.0),
	p_size: float = 3.0
) -> void:
	damage = p_damage
	damage_type = p_damage_type
	knockback = p_knockback
	pierce_remaining = p_pierce
	lifetime = p_lifetime
	gravity = p_gravity
	element = p_element
	_instigator = p_instigator
	_owner_id = p_instigator.get_instance_id() if p_instigator != null else 0
	_bullet_color = p_color
	_bullet_size = p_size
	_hit_ids.clear()
	_trail.clear()
	if _visual != null:
		_visual.modulate = Color(1, 1, 1, 1)
		_visual.queue_redraw()


## Resets motion and state. Called by the pool on acquire and release.
func _on_pool_acquire() -> void:
	_hit_ids.clear()
	_trail.clear()
	gravity_scale = 0.0
	angular_velocity = 0.0
	linear_velocity = Vector2.ZERO
	if _hit_detector != null:
		_hit_detector.set_deferred(&"monitoring", true)
	if _visual != null:
		_visual.modulate = Color(1, 1, 1, 1)


func _on_pool_release() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_hit_ids.clear()
	_trail.clear()
	_instigator = null
	_owner_id = 0
	if _hit_detector != null:
		_hit_detector.set_deferred(&"monitoring", false)


func _despawn() -> void:
	# Bullets live in a pool owned by ProjectileSpawner. Falling back to
	# queue_free() keeps a stray bullet from leaking when no pool claimed it.
	if has_meta(&"pool_owner"):
		var pool: ObjectPool = get_meta(&"pool_owner") as ObjectPool
		if pool != null:
			pool.release(self)
			return
	queue_free()


## Static factory for pool prewarming. Instances are inert until configured.
static func create_bullet() -> Bullet:
	var bullet := Bullet.new()
	bullet.freeze = true
	return bullet