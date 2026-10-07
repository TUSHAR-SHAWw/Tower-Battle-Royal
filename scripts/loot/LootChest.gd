class_name LootChest
extends Area2D

## Interactive chest that drops loot when opened.

signal opened(player: Node, drops: Array)

@export var loot_table: LootTable
@export var interaction_radius: float = 48.0
@export var open_time: float = 0.8
@export var auto_open: bool = false

var _opened: bool = false
var _opening: bool = false
var _open_timer: float = 0.0
var _chest_sprite: Sprite2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	add_child(shape)
	shape.owner = self
	_chest_sprite = Sprite2D.new()
	_chest_sprite.name = "ChestSprite"
	_chest_sprite.texture = MapAssetLibrary.tile_texture("tile_0064.png")
	_chest_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chest_sprite.scale = Vector2.ONE * 2.0
	add_child(_chest_sprite)
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if _opening:
		_open_timer += delta
		var progress := clampf(_open_timer / open_time, 0.0, 1.0)
		_chest_sprite.position.y = lerpf(0.0, -8.0, progress)
		_chest_sprite.modulate = Color(1.0, 0.75 + progress * 0.25, 0.55 + progress * 0.45)
		if _open_timer >= open_time:
			_finish_open()


func _on_area_entered(area: Area2D) -> void:
	if _opened or _opening:
		return
	if area.is_in_group("player"):
		if auto_open:
			start_open(area)
		else:
			# Could show interaction prompt here
			pass


func _on_area_exited(area: Area2D) -> void:
	if _opening and not auto_open:
		_cancel_open()


func start_open(player: Node) -> void:
	if _opened or _opening:
		return
	_opening = true
	_open_timer = 0.0


func _cancel_open() -> void:
	_opening = false
	_open_timer = 0.0


func _finish_open() -> void:
	_opened = true
	_opening = false
	set_deferred(&"monitoring", false)
	
	var drops: Array = []
	if loot_table != null:
		drops = loot_table.roll_guaranteed(1)
		for result in drops:
			# Spawn item pickup
			var pickup := ItemPickup.new()
			pickup.item = result.item
			pickup.count = result.count
			pickup.global_position = global_position + Vector2(randf_range(-32, 32), randf_range(-32, 32))
			get_parent().add_child(pickup)
	
	opened.emit(get_parent(), drops)
	queue_free()
