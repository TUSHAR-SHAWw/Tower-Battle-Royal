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

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = PhysicsLayers.LOOT
	collision_mask = PhysicsLayers.PLAYER
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	shape.owner = self
	
	area_entered.connect(_on_area_entered)
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
	if area.is_in_group("player"):
		var inventory := area.get_node_or_null("InventoryComponent")
		if inventory != null:
			var added := inventory.add_item(item, count)
			if added > 0:
				picked_up.emit(item, added)
				if added < count:
					# Remainder stays
					count -= added
				else:
					queue_free()


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
		draw_string(ThemeDB.get_default_theme().get_font("font", "Label"), Vector2(14, 4), str(count), Color(1, 1, 1, 1), 0, 0, 12)