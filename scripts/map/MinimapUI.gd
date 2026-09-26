class_name MinimapUI
extends Control

## Corner minimap showing current floor, explored areas, player position.

@export var map_resource: MapResource
@export var minimap_size: Vector2 = Vector2(200, 200)
@export var position_corner: int = 3  # 0=TL, 1=TR, 2=BL, 3=BR
@export var padding: float = 20.0

var _player: Node = null
var _explored_floors: Array[int] = []
var _current_floor: int = 1

func _ready() -> void:
	# Anchor to corner
	_setup_anchors()
	
	# Find player
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var player_instance := tree.current_scene.get_node_or_null("PlayerInstance")
		var player := tree.current_scene.get_node_or_null("Player")
		_player = player_instance if player_instance != null else player


func _setup_anchors() -> void:
	anchor_left = 1.0 if position_corner in [1, 3] else 0.0
	anchor_right = 1.0 if position_corner in [1, 3] else 0.0
	anchor_top = 1.0 if position_corner in [2, 3] else 0.0
	anchor_bottom = 1.0 if position_corner in [2, 3] else 0.0
	
	offset_left = padding if position_corner in [0, 2] else -minimap_size.x - padding
	offset_right = padding if position_corner in [0, 2] else -minimap_size.x - padding
	offset_top = padding if position_corner in [0, 1] else -minimap_size.y - padding
	offset_bottom = padding if position_corner in [0, 1] else -minimap_size.y - padding
	
	custom_minimum_size = minimap_size


func set_current_floor(floor_id: int) -> void:
	_current_floor = floor_id


func mark_floor_explored(floor_id: int) -> void:
	if not _explored_floors.has(floor_id):
		_explored_floors.append(floor_id)


func _draw() -> void:
	if map_resource == null:
		return
	
	# Background
	draw_rect(Rect2(Vector2.ZERO, minimap_size), map_resource.unexplored_color)
	draw_rect(Rect2(Vector2.ZERO, minimap_size), Color(0, 0, 0, 0.5), false, 2.0)
	
	# Draw tower floors as vertical stack
	var map_rect := Rect2(0, 0, minimap_size.x, minimap_size.y)
	var tower_rect_height := map_resource.total_floors * map_resource.cell_size
	var start_y := (minimap_size.y - tower_rect_height) * 0.5
	
	# Draw connections
	_draw_connections(start_y)
	
	# Draw floors
	for i in range(map_resource.total_floors):
		var floor_id := i + 1
		var floor_y := start_y + (map_resource.total_floors - 1 - i) * map_resource.cell_size
		var floor_rect := Rect2((minimap_size.x - map_resource.cell_size) * 0.5, floor_y, map_resource.cell_size, map_resource.cell_size)
		
		var color := map_resource.unexplored_color
		if floor_id == _current_floor:
			color = map_resource.current_floor_color
		elif _explored_floors.has(floor_id):
			color = map_resource.explored_color
		elif map_resource.central_platform_floor == floor_id:
			color = map_resource.central_platform_color
		
		draw_rect(floor_rect, color)
		
		# Floor number
		var font := ThemeDB.get_default_theme().get_font("font", "Label")
		if map_resource.central_platform_floor == floor_id:
			draw_string(font, floor_rect.position + Vector2(2, map_resource.cell_size - 4), "C", 0, 0, 10, Color(1, 1, 1, 1))
		else:
			draw_string(font, floor_rect.position + Vector2(2, map_resource.cell_size - 4), str(floor_id), 0, 0, 10, Color(1, 1, 1, 0.8))
	
	# Draw player indicator on current floor
	if _player != null and map_resource.total_floors > 0:
		var floor_y := start_y + (map_resource.total_floors - _current_floor) * map_resource.cell_size
		var center_x := minimap_size.x * 0.5
		draw_circle(Vector2(center_x, floor_y + map_resource.cell_size * 0.5), 4.0, Color(1, 1, 0, 1))
		draw_circle(Vector2(center_x, floor_y + map_resource.cell_size * 0.5), 4.0, Color(0, 0, 0, 1), false, 1.0)
		draw_circle(Vector2(center_x, floor_y + map_resource.cell_size * 0.5), 4.0, Color(0, 0, 0, 1), false, 1.0)


func _draw_connections(start_y: float) -> void:
	for i in range(map_resource.total_floors):
		var floor_id := i + 1
		var connections := map_resource.get_connected_floors(floor_id)
		if connections.is_empty():
			continue
		
		var floor_y := start_y + (map_resource.total_floors - 1 - i) * map_resource.cell_size
		var center_x := size.x * 0.5
		var center_y := floor_y + map_resource.cell_size * 0.5
		
		for target_id in connections:
			var target_y := start_y + (map_resource.total_floors - target_id) * map_resource.cell_size + map_resource.cell_size * 0.5
			draw_line(Vector2(center_x, center_y), Vector2(center_x, target_y), map_resource.connection_color, 2.0)