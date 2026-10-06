class_name MinimapUI
extends CanvasLayer

## Corner minimap showing current floor, explored areas, player position.
##
## CanvasLayer can't draw directly, so a child Control does the drawing.

@export var map_resource: MapResource
@export var minimap_size: Vector2 = Vector2(200, 200)
@export var position_corner: int = 3  # 0=TL, 1=TR, 2=BL, 3=BR
@export var padding: float = 20.0

var _player: Node = null
var _explored_floors: Array[int] = []
var _current_floor: int = 1
var _draw_control: Control = null


func _ready() -> void:
	var canvas := PixelArtScale.ensure_ui_root(self)

	# Create a child Control that does the drawing (CanvasLayer can't draw)
	_draw_control = Control.new()
	_draw_control.name = "DrawControl"
	_draw_control.custom_minimum_size = minimap_size
	_draw_control.size = minimap_size
	_draw_control.draw.connect(_on_draw)
	canvas.add_child(_draw_control)

	# Apply anchors to the child Control (CanvasLayer has no anchors)
	_setup_anchors()

	# Find player
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var player_instance := tree.current_scene.get_node_or_null("PlayerInstance")
		var player := tree.current_scene.get_node_or_null("Player")
		_player = player_instance if player_instance != null else player


func _setup_anchors() -> void:
	_draw_control.anchor_left = 1.0 if position_corner in [1, 3] else 0.0
	_draw_control.anchor_right = 1.0 if position_corner in [1, 3] else 0.0
	_draw_control.anchor_top = 1.0 if position_corner in [2, 3] else 0.0
	_draw_control.anchor_bottom = 1.0 if position_corner in [2, 3] else 0.0

	_draw_control.offset_left = padding if position_corner in [0, 2] else -minimap_size.x - padding
	_draw_control.offset_right = padding if position_corner in [0, 2] else -minimap_size.x - padding
	_draw_control.offset_top = padding if position_corner in [0, 1] else -minimap_size.y - padding
	_draw_control.offset_bottom = padding if position_corner in [0, 1] else -minimap_size.y - padding


func set_current_floor(floor_id: int) -> void:
	_current_floor = floor_id
	if _draw_control != null:
		_draw_control.queue_redraw()


func mark_floor_explored(floor_id: int) -> void:
	if not _explored_floors.has(floor_id):
		_explored_floors.append(floor_id)
	if _draw_control != null:
		_draw_control.queue_redraw()


func _on_draw() -> void:
	if map_resource == null:
		return

	# Background
	_draw_control.draw_rect(Rect2(Vector2.ZERO, minimap_size), map_resource.unexplored_color)
	_draw_control.draw_rect(Rect2(Vector2.ZERO, minimap_size), Color(0, 0, 0, 0.5), false, 2.0)

	# Draw tower floors as vertical stack
	var tower_rect_height := map_resource.total_floors * map_resource.cell_size
	var start_y := (minimap_size.y - tower_rect_height) * 0.5

	# Draw connections
	_draw_connections(start_y)

	# Draw floors
	for i in range(map_resource.total_floors):
		var floor_id := i + 1
		var floor_y := start_y + (map_resource.total_floors - 1 - i) * map_resource.cell_size
		var floor_rect := Rect2(
			(minimap_size.x - map_resource.cell_size) * 0.5,
			floor_y,
			map_resource.cell_size,
			map_resource.cell_size
		)

		var color := map_resource.unexplored_color
		if floor_id == _current_floor:
			color = map_resource.current_floor_color
		elif _explored_floors.has(floor_id):
			color = map_resource.explored_color
		elif map_resource.central_platform_floor == floor_id:
			color = map_resource.central_platform_color

		_draw_control.draw_rect(floor_rect, color)

		# Floor number
		var font := ThemeDB.get_default_theme().get_font("font", "Label")
		var label_pos := floor_rect.position + Vector2(2, map_resource.cell_size - 4)
		if map_resource.central_platform_floor == floor_id:
			_draw_control.draw_string(font, label_pos, "C", 0, 0, 10, Color(1, 1, 1, 1))
		else:
			_draw_control.draw_string(font, label_pos, str(floor_id), 0, 0, 10, Color(1, 1, 1, 0.8))

	# Draw player indicator on current floor
	if _player != null and map_resource.total_floors > 0:
		var floor_y := start_y + (map_resource.total_floors - _current_floor) * map_resource.cell_size
		var center_x := minimap_size.x * 0.5
		var indicator_pos := Vector2(center_x, floor_y + map_resource.cell_size * 0.5)
		_draw_control.draw_circle(indicator_pos, 4.0, Color(1, 1, 0, 1))
		_draw_control.draw_circle(indicator_pos, 4.0, Color(0, 0, 0, 1), false, 1.0)
		_draw_control.draw_circle(indicator_pos, 4.0, Color(0, 0, 0, 1), false, 1.0)


func _draw_connections(start_y: float) -> void:
	for i in range(map_resource.total_floors):
		var floor_id := i + 1
		var connections := map_resource.get_connected_floors(floor_id)
		if connections.is_empty():
			continue

		var floor_y := start_y + (map_resource.total_floors - 1 - i) * map_resource.cell_size
		var center_x := minimap_size.x * 0.5
		var center_y := floor_y + map_resource.cell_size * 0.5

		for target_id in connections:
			var target_y := start_y + (map_resource.total_floors - target_id) * map_resource.cell_size + map_resource.cell_size * 0.5
			_draw_control.draw_line(
				Vector2(center_x, center_y),
				Vector2(center_x, target_y),
				map_resource.connection_color,
				2.0
			)
