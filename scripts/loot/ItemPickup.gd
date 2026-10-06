class_name ItemPickup
extends Area2D

## Physical item on ground that player can pick up.

signal picked_up(item: ItemResource, count: int)

@export var item: ItemResource
@export var count: int = 1
@export var lifetime: float = 60.0
@export var bob_amount: float = 4.0
@export var bob_speed: float = 2.0

var _spawn_time: float = 0.0
var _base_y: float = 0.0
var _collected: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = PhysicsLayers.LOOT
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PLAYER_HURTBOX
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	shape.owner = self
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_base_y = global_position.y
	_spawn_time = Time.get_ticks_msec() / 1000.0


func _physics_process(delta: float) -> void:
	# Bob animation
	var t := (Time.get_ticks_msec() / 1000.0) - _spawn_time
	global_position.y = _base_y + sin(t * bob_speed) * bob_amount
	
	# Lifetime
	if Time.get_ticks_msec() / 1000.0 - _spawn_time >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	_try_pickup(area)


func _on_body_entered(body: Node2D) -> void:
	_try_pickup(body)


func _try_pickup(detected: Node) -> void:
	if _collected or item == null or count <= 0:
		return

	var player := _resolve_player(detected)
	if player == null:
		return
	var inventory := player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inventory == null:
		return

	var added := inventory.add_item(item, count)
	if added <= 0:
		return

	count -= added
	if count <= 0:
		_collected = true
		set_deferred(&"monitoring", false)
		queue_free()
	picked_up.emit(item, added)


func _resolve_player(detected: Node) -> Node:
	var node := detected
	while node != null:
		if node.is_in_group(&"player"):
			return node
		node = node.get_parent()
	return null


func _draw() -> void:
	if item == null:
		return
	
	# Draw item icon or placeholder
	var color := item.icon_color
	if item.icon_texture != null:
		draw_texture(item.icon_texture, Vector2(-16, -16), color)
	else:
		draw_rect(Rect2(-12, -12, 24, 24), color)
	
	# Count
	if count > 1:
		draw_string(
			ThemeDB.get_default_theme().get_font("font", "Label"),
			Vector2(14, 4),
			str(count),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1, 1, 1, 1)
		)