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
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if _opening:
		_open_timer += delta
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
	monitoring = false
	
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


func _draw() -> void:
	if _opened:
		return
	
	# Draw chest box
	var color := Color(0.4, 0.25, 0.1, 1.0) if not _opening else Color(0.6, 0.4, 0.15, 1.0)
	draw_rect(Rect2(-16, -16, 32, 32), color)
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.2, 0.1, 0.05, 1.0), false, 2.0)
	
	# Lid
	var lid_y := -16
	if _opening:
		var progress := _open_timer / open_time
		lid_y = lerp(-16, -32, progress)
	draw_rect(Rect2(-18, lid_y - 4, 36, 4), Color(0.3, 0.18, 0.08, 1.0))
	draw_rect(Rect2(-18, lid_y - 4, 36, 4), Color(0.1, 0.05, 0.02, 1.0), false, 2.0)
	
	# Lock
	draw_rect(Rect2(-4, 0, 8, 8), Color(0.6, 0.5, 0.2, 1.0))