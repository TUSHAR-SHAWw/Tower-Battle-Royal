class_name WorldMapUI
extends Control

## Full-screen world map with floor navigation, fog of war, and teleport.

signal floor_selected(floor_id: int)
signal map_closed()

@export var map_resource: MapResource
@export var background_color: Color = Color(0.05, 0.05, 0.1, 0.95)
@export var border_color: Color = Color(0.2, 0.6, 1.0, 1.0)

var _player: Node = null
var _explored_floors: Array[int] = []
var _current_floor: int = 1
var _selected_floor: int = 1
var _visible: bool = false

func _ready() -> void:
	visible = false
	_visible = false
	
	# Full screen layout
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	# Find player
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var player_instance := tree.current_scene.get_node_or_null("PlayerInstance")
		var player := tree.current_scene.get_node_or_null("Player")
		_player = player_instance if player_instance != null else player


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_M:
			_toggle_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			_toggle_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP and _visible:
			_select_floor(_selected_floor - 1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN and _visible:
			_select_floor(_selected_floor + 1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and _visible:
			_confirm_travel()
			get_viewport().set_input_as_handled()


func _toggle_map() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		# Refresh explored floors from player
		if _player != null:
			var tower := _player.get_node_or_null("TowerController")
			if tower != null and tower.has_method("get_explored_floors"):
				_explored_floors = tower.get_explored_floors()
		grab_focus()
	else:
		map_closed.emit()


func _select_floor(delta: int) -> void:
	if map_resource == null:
		return
	_selected_floor = clamp(_selected_floor + delta, 1, map_resource.total_floors)


func _confirm_travel() -> void:
	if _selected_floor != _current_floor and _player != null:
		var tower := _player.get_node_or_null("TowerController")
		if tower != null and tower.has_method("start_travel"):
			tower.start_travel(_selected_floor)
	_toggle_map()


func set_current_floor(floor_id: int) -> void:
	_current_floor = floor_id
	_selected_floor = floor_id


func mark_floor_explored(floor_id: int) -> void:
	if not _explored_floors.has(floor_id):
		_explored_floors.append(floor_id)


func _draw() -> void:
	if not _visible or map_resource == null:
		return
	
	var rect := get_rect()
	var center := rect.size * 0.5
	
	# Background
	draw_rect(Rect2(Vector2.ZERO, rect.size), background_color)
	draw_rect(Rect2(Vector2.ZERO, rect.size), border_color, false, 3.0)
	
	# Title
	var font := ThemeDB.get_default_theme().get_font("font", "Label")
	draw_string(font, Vector2(20, 40), "%s - World Map" % map_resource.map_name, 0, 0, 28, Color(1, 0.9, 0.2, 1))
	
	# Draw tower
	var tower_width := rect.size.x * 0.3
	var tower_height := rect.size.y * 0.8
	var tower_rect := Rect2(center.x - tower_width * 0.5, center.y - tower_height * 0.5, tower_width, tower_height)
	draw_rect(tower_rect, Color(0.08, 0.08, 0.12, 1.0))
	draw_rect(tower_rect, Color(0.2, 0.4, 0.6, 1.0), false, 2.0)
	
	# Floor cells
	var cell_height := tower_height / map_resource.total_floors
	var cell_width := tower_width * 0.8
	var cell_x := tower_rect.position.x + (tower_width - cell_width) * 0.5
	
	for i in range(map_resource.total_floors):
		var floor_id := map_resource.total_floors - i  # top to bottom
		var floor_y := tower_rect.position.y + i * cell_height
		var floor_rect := Rect2(cell_x, floor_y, cell_width, cell_height * 0.9)
		
		var color := Color(0.15, 0.15, 0.2, 1.0)
		var border_col := Color(0.3, 0.3, 0.4, 1.0)
		
		if floor_id == _current_floor:
			color = Color(0.1, 0.3, 0.5, 1.0)
			border_col = Color(0.2, 0.8, 1.0, 1.0)
		elif _explored_floors.has(floor_id):
			color = Color(0.15, 0.25, 0.4, 1.0)
			border_col = Color(0.4, 0.6, 0.8, 1.0)
		elif map_resource.central_platform_floor == floor_id:
			color = Color(0.25, 0.2, 0.05, 1.0)
			border_col = Color(1.0, 0.9, 0.3, 1.0)
		
		if floor_id == _selected_floor:
			border_col = Color(1.0, 1.0, 0.2, 1.0)
			color = Color(0.2, 0.4, 0.6, 1.0)
		
		draw_rect(floor_rect, color)
		var border_width: float = 3.0 if floor_id == _selected_floor else 1.0
		draw_rect(floor_rect, border_col, false, border_width)
		
		# Floor label
		var label := "FLOOR %d" % floor_id
		if map_resource.central_platform_floor == floor_id:
			label = "CENTRAL PLATFORM"
		draw_string(font, floor_rect.position + Vector2(10, floor_rect.size.y * 0.5 + 8), label, 0, 0, 16, Color(1, 1, 1, 0.9))
		
		# Status
		var status := ""
		if floor_id == _current_floor:
			status = "← CURRENT"
		elif _explored_floors.has(floor_id):
			status = "EXPLORED"
		elif map_resource.central_platform_floor == floor_id:
			status = "HUB"
		else:
			status = "UNEXPLORED"
		draw_string(font, floor_rect.position + Vector2(floor_rect.size.x - 120, floor_rect.size.y * 0.5 + 8), status, 2, 0, 12, Color(1, 1, 1, 0.6))
	
	# Legend
	var legend_y := tower_rect.position.y + tower_height + 20
	draw_string(font, Vector2(tower_rect.position.x, legend_y), 
		"[UP/DOWN] Select Floor   [ENTER] Travel   [TAB/M] Close   [ESC] Cancel", 
		0, 0, 14, Color(0.8, 0.8, 0.8, 1))
	
	# Current floor info
	draw_string(font, Vector2(20, rect.size.y - 40), 
		"Current: Floor %d (%s)" % [_current_floor, _get_floor_status(_current_floor)], 
		0, 0, 16, Color(0.2, 1, 0.4, 1))


func _get_floor_status(floor_id: int) -> String:
	if floor_id == _current_floor:
		return "CURRENT"
	if _explored_floors.has(floor_id):
		return "EXPLORED"
	if map_resource.central_platform_floor == floor_id:
		return "CENTRAL HUB"
	return "UNEXPLORED"