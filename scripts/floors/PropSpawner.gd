class_name PropSpawner
extends Node2D

## Spawns decorative props (desk, cabinet, lamp, etc.) inside a floor room,
## avoiding the central shaft. Props are drawn as flat-vector placeholder art
## (code-drawn polygon shapes with bold outlines) so they match the flat-vector
## direction and require no downloaded assets.
##
## Placed here — not in FloorController — so the prop layer stays independent
## of tile layers and can be edited or disabled per-theme.

@export var floor_controller: FloorController = null
@export var theme: FloorTheme = null

## Total props to place; taken from the theme in _ready().
@export var prop_count: int = 6

## Size of each prop, in world pixels; taken from the theme in _ready().
@export var prop_size: float = 42.0

## Visual node for the props — a single Node2D child so everything lives in one
## layer and can be hidden or moved as a group later.
@onready var visual: Node2D = $PropVisual if has_node("PropVisual") else _create_visual()


func _ready() -> void:
	if theme == null and floor_controller != null and floor_controller.floor_data != null:
		theme = floor_controller.floor_data.theme
	if theme == null:
		return
	prop_count = theme.prop_count
	prop_size = theme.prop_size


func spawn() -> void:
	if floor_controller == null or floor_controller.floor_data == null:
		return
	_spawn_props()


func _create_visual() -> Node2D:
	var v := Node2D.new()
	v.name = "PropVisual"
	v.z_index = 5
	v.z_as_relative = false
	add_child(v)
	v.owner = self
	return v


func _spawn_props() -> void:
	var bounds := floor_controller.floor_data.bounds
	var shaft_half := floor_controller._shaft_half_width()
	var slab_top := bounds.position.y + bounds.size.y - (FloorTileLayout.SLAB_ROWS * FloorTileLayout.TILE)

	# Side rooms: the alcove is the area between the wall and the shaft opening,
	# at half the slab thickness so props read as sitting *inside* the room, not
	# floating over it.
	var side_margin := prop_size * 2.0
	var left_room := Vector2(bounds.position.x + side_margin, slab_top - prop_size)
	var right_room_x := bounds.position.x + bounds.size.x - prop_size - side_margin

	var props := theme.prop_types if theme != null else PackedStringArray(["desk"])

	# Place props evenly on both sides of the shaft; never over it.
	var count_per_side := prop_count / 2
	for i in range(count_per_side):
		var prop := _pick_prop()
		# Spread props horizontally within each side, vertically near slab top.
		var t := float(i) / maxf(count_per_side - 1, 1)
		var x := left_room.x + t * (bounds.position.x + bounds.size.x * 0.5 - shaft_half - side_margin - left_room.x)
		var y := slab_top - prop_size * randf_range(0.7, 1.2)
		_spawn_prop_at(prop, Vector2(x, y))

		var x2 := bounds.position.x + bounds.size.x * 0.5 + shaft_half + side_margin + t * (bounds.position.x + bounds.size.x - side_margin - (bounds.position.x + bounds.size.x * 0.5 + shaft_half + side_margin))
		var y2 := slab_top - prop_size * randf_range(0.7, 1.2)
		_spawn_prop_at(prop, Vector2(x2, y2))


func _pick_prop() -> String:
	var props := theme.prop_types if theme != null else PackedStringArray(["desk"])
	if props.is_empty():
		return "desk"
	return props[randi() % props.size()]


func _spawn_prop_at(name: String, pos: Vector2) -> void:
	if visual == null:
		return
	var prop_visual := PropVisual.new()
	prop_visual.theme = theme
	prop_visual.prop_size_points = Vector2(prop_size, prop_size)
	prop_visual.prop_type = name
	prop_visual.name = "Prop_" + prop + "_%d" % randi()
	prop_visual.global_position = pos
	visual.add_child(prop_visual)
