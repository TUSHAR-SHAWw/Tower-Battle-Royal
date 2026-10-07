class_name MinimapUI
extends CanvasLayer

@export var map_resource: MapResource
@export var position_corner: int = 3
@export var padding: float = 12.0

var _tower: TowerController
var _platform: CentralPlatformController
var _player: Node2D
var _explored_floors: Array[int] = []
var _current_floor: int = 1
var _row_labels: Array[Label] = []
var _row_floor_ids: Array[int] = []
var _status_label: Label
var _scroll_container: ScrollContainer
var _last_scroll_floor: int = -1


func _ready() -> void:
	var root := PixelArtScale.ensure_ui_root(self)
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var player := current_scene.get_node_or_null("PlayerInstance")
		if player == null:
			player = current_scene.get_node_or_null("Player")
		_player = player as Node2D
		_tower = current_scene.get_node_or_null("TowerController") as TowerController
		_platform = current_scene.get_node_or_null("CentralPlatform") as CentralPlatformController
		if _tower != null:
			_current_floor = _tower.get_current_floor_id()
	if map_resource != null:
		map_resource.synchronize_floor_count(_floor_count())
	_build_panel(root)
	_refresh_rows()


func _process(_delta: float) -> void:
	if _tower != null:
		_current_floor = _get_player_floor()
	_refresh_rows()


func _build_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TowerMinimap"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -220.0 - padding
	panel.offset_top = -270.0 - padding
	panel.offset_right = -padding
	panel.offset_bottom = -padding
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)

	var title := Label.new()
	title.text = "TOWER / %02d" % _floor_count()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	stack.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(_status_label)

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(_scroll_container)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(rows)

	for floor_id in range(_floor_count(), 0, -1):
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size.y = 17.0
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = MapAssetLibrary.floor_theme_color(_floor_data(floor_id)).darkened(0.55)
		row_style.bg_color.a = 0.8
		row_panel.add_theme_stylebox_override("panel", row_style)
		rows.add_child(row_panel)
		var row := HBoxContainer.new()
		row_panel.add_child(row)
		var marker := Label.new()
		marker.custom_minimum_size.x = 30.0
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.name = "Markers"
		marker.add_theme_font_size_override("font_size", 11)
		row.add_child(marker)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		_row_labels.append(label)
		_row_floor_ids.append(floor_id)


func _refresh_rows() -> void:
	if _status_label == null:
		return
	var platform_floor := _platform.get_display_floor() if _platform != null else -1
	var direction := _platform.get_direction_name() if _platform != null else "idle"
	var player_side := _get_player_side()
	_current_floor = _get_player_floor()
	_status_label.text = "YOU %02d %s   LIFT %02d %s" % [
		_current_floor, player_side, platform_floor, direction.to_upper()
	]
	for index in range(_row_labels.size()):
		var floor_id := _row_floor_ids[index]
		var label := _row_labels[index]
		var row := label.get_parent() as HBoxContainer
		var marker := row.get_node("Markers") as Label
		var marker_text := ""
		if floor_id == _current_floor:
			marker_text += "YOU " + player_side.left(1) + " "
		if floor_id == platform_floor:
			marker_text += "LIFT"
		marker.text = marker_text
		marker.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75) if floor_id == _current_floor else Color(1.0, 0.8, 0.3))
		var data := _floor_data(floor_id)
		var display_name := MapAssetLibrary.floor_theme_name(data)
		label.text = "%02d  %s" % [floor_id, display_name.to_upper()]
		label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0) if floor_id == _current_floor else Color(0.85, 0.88, 0.93))
	if _last_scroll_floor != _current_floor:
		_last_scroll_floor = _current_floor
		call_deferred("_scroll_to_floor", _current_floor)


func _scroll_to_floor(floor_id: int) -> void:
	if _scroll_container == null:
		return
	var index := _row_floor_ids.find(floor_id)
	if index < 0 or index >= _row_labels.size():
		return
	_scroll_container.ensure_control_visible(_row_labels[index])


func _get_player_floor() -> int:
	if _platform != null and _player != null and _platform.get_players().has(_player):
		return _platform.get_display_floor()
	return _tower.get_current_floor_id() if _tower != null else _current_floor


func _get_player_side() -> String:
	if _player == null or _tower == null:
		return ""
	var floor_node := _tower.get_current_floor() as FloorController
	if floor_node == null:
		return ""
	var center: float = floor_node.to_global(Vector2(floor_node.shaft_center_x(), 0.0)).x
	var offset: float = _player.global_position.x - center
	if absf(offset) < 80.0:
		return "CENTER"
	return "LEFT" if offset < 0.0 else "RIGHT"


func _floor_count() -> int:
	if _tower != null and not _tower.tower_data.is_empty():
		return _tower.tower_data.size()
	if map_resource != null:
		return map_resource.total_floors
	return 50


func _floor_data(floor_id: int) -> FloorData:
	if _tower == null or floor_id < 1 or floor_id > _tower.tower_data.size():
		return null
	var data := _tower.tower_data[floor_id - 1]
	return data.floor_data if data != null else null


func set_current_floor(floor_id: int) -> void:
	_current_floor = floor_id
	_refresh_rows()


func mark_floor_explored(floor_id: int) -> void:
	if not _explored_floors.has(floor_id):
		_explored_floors.append(floor_id)
