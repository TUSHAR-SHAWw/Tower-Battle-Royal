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
var _icon: Sprite2D
var _count_label: Label

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
	_build_visual()
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
	else:
		_update_visual()
	picked_up.emit(item, added)


func _resolve_player(detected: Node) -> Node:
	var node := detected
	while node != null:
		if node.is_in_group(&"player"):
			return node
		node = node.get_parent()
	return null


func _build_visual() -> void:
	_icon = Sprite2D.new()
	_icon.name = "ItemIcon"
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.scale = Vector2.ONE * 2.0
	add_child(_icon)
	_count_label = Label.new()
	_count_label.name = "StackCount"
	_count_label.position = Vector2(12.0, -18.0)
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 1))
	_count_label.add_theme_constant_override("outline_size", 4)
	add_child(_count_label)
	_update_visual()


func _update_visual() -> void:
	if _icon == null or _count_label == null:
		return
	_icon.texture = MapAssetLibrary.item_texture(item)
	_icon.modulate = item.icon_color if item != null else Color.WHITE
	_count_label.text = str(count) if count > 1 else ""