class_name TravelPortal
extends Area2D

## Portal that triggers floor travel when player enters.
## Visual: pulsing ring + particle effect.

signal activated(player: Node)

@export var target_floor: int = 0  # 0 = next floor
@export var activation_radius: float = 64.0
@export var cooldown: float = 2.0

var _active: bool = true
var _cooldown_timer: float = 0.0
var _pulse_phase: float = 0.0
var _portal_sprite: Sprite2D
var _base_scale: Vector2

func _ready() -> void:
	# A portal can be instantiated from another area's physics callback during
	# floor travel. Keep it inactive until its shape is attached outside query flush.
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	collision_layer = 0
	# Must watch both the player body (PLAYER) and its hurtbox area
	# (PLAYER_HURTBOX), otherwise the portal never detects anyone.
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PLAYER_HURTBOX
	_create_visual()

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	call_deferred(&"_create_collision_shape")


func _create_collision_shape() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = activation_radius
	shape.shape = circle
	add_child(shape)
	shape.owner = self
	set_deferred(&"monitoring", _active)


func _physics_process(delta: float) -> void:
	if not _active:
		_cooldown_timer = max(0.0, _cooldown_timer - delta)
		if _cooldown_timer <= 0.0:
			_active = true
			set_deferred(&"monitoring", true)
	
	_pulse_phase += delta * 3.0
	_update_visual()


func _on_area_entered(area: Area2D) -> void:
	_try_activate(area)


func _on_body_entered(body: Node2D) -> void:
	_try_activate(body)


## Walks up from a detected node to the owning player root, then fires once.
func _try_activate(detected: Node) -> void:
	if not _active or detected == null:
		return
	var player := _resolve_player(detected)
	if player == null:
		return
	_active = false
	# Cannot toggle monitoring from inside a physics signal; defer it.
	set_deferred(&"monitoring", false)
	_cooldown_timer = cooldown
	activated.emit(player)


## The portal can detect either the player body or its Hurtbox child, so climb
## to whichever ancestor is actually the player.
func _resolve_player(detected: Node) -> Node:
	var node: Node = detected
	while node != null:
		if node.is_in_group(&"player"):
			return node
		# The Hurtbox has no group, so climb until we hit something that does.
		node = node.get_parent()
	return null


func _create_visual() -> void:
	_portal_sprite = Sprite2D.new()
	_portal_sprite.name = "PortalSprite"
	_portal_sprite.texture = MapAssetLibrary.tile_texture("tile_0073.png", true)
	_portal_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portal_sprite.z_index = 3
	_portal_sprite.z_as_relative = false
	_base_scale = Vector2.ONE * (activation_radius * 1.5 / 18.0)
	_portal_sprite.scale = _base_scale
	add_child(_portal_sprite)


func _update_visual() -> void:
	if _portal_sprite == null:
		return
	var pulse := sin(_pulse_phase) * 0.3 + 0.7
	_portal_sprite.scale = _base_scale * (0.9 + pulse * 0.1)
	_portal_sprite.modulate = Color(0.38, 0.86, 1.0, pulse if _active else 0.35)
