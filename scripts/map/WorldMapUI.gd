class_name WorldMapUI
extends CanvasLayer

signal floor_selected(floor_id: int)
signal map_closed()

@export var map_resource: MapResource

var _tower: TowerController
var _platform: CentralPlatformController
var _player: Node2D
var _explored_floors: Array[int] = []
var _current_floor: int = 1
var _selected_floor: int = 1
var _open: bool = false
var _rows: Array[Button] = []
var _row_floor_ids: Array[int] = []
var _status_label: Label
var _last_refresh_key: String = ""


func _ready() -> void:
	visible = false
	var scene := get_tree().current_scene
	if scene != null:
		var player := scene.get_node_or_null("PlayerInstance")
		if player == null:
			player = scene.get_node_or_null("Player")
		_player = player as Node2D
		_tower = scene.get_node_or_null("TowerController") as TowerController
		_platform = scene.get_node_or_null("CentralPlatform") as CentralPlatformController
		if _tower != null:
			_current_floor = _tower.get_current_floor_id()
			_selected_floor = _current_floor
	if map_resource != null:
		map_resource.synchronize_floor_count(_floor_count())
	var root := PixelArtScale.ensure_ui_root(self)
	_build_map(root)
	_refresh_rows()


func _process(_delta: float) -> void:
	_current_floor = _get_player_floor()
	var lift_floor := _platform.get_display_floor() if _platform != null else -1
	var direction := _platform.get_direction_name() if _platform != null else "IDLE"
	var player_side := _get_player_side()
	var refresh_key := "%d:%d:%s:%d:%s" % [
		_current_floor, lift_floor, direction, _selected_floor, player_side
	]
	if refresh_key != _last_refresh_key:
		_refresh_rows()


func _build_map(root: Control) -> void:
	var overlay := ColorRect.new()
	overlay.name = "DimBackground"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.02, 0.035, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "WorldMapPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48.0
	panel.offset_top = 32.0
	panel.offset_right = -48.0
	panel.offset_bottom = -32.0
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "SPIRE OF ETERNITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	stack.add_child(title)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for floor_id in range(_floor_count(), 0, -1):
		var button := Button.new()
		button.custom_minimum_size.y = 36.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_floor_selected.bind(floor_id))
		list.add_child(button)
		_rows.append(button)
		_row_floor_ids.append(floor_id)
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = MapAssetLibrary.floor_theme_color(_floor_data(floor_id)).darkened(0.6)
		row_style.bg_color.a = 0.8
		button.add_theme_stylebox_override("normal", row_style)
		var hover_style := row_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = hover_style.bg_color.lightened(0.15)
		button.add_theme_stylebox_override("hover", hover_style)

	var hint := Label.new()
	hint.text = "UP / DOWN to select   ENTER to travel   TAB or ESC to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB or event.keycode == KEY_M:
		_toggle_map()
		get_viewport().set_input_as_handled()
	elif _open and event.keycode == KEY_ESCAPE:
		_toggle_map()
		get_viewport().set_input_as_handled()
	elif _open and event.keycode == KEY_UP:
		_select_floor(_selected_floor + 1)
		get_viewport().set_input_as_handled()
	elif _open and event.keycode == KEY_DOWN:
		_select_floor(_selected_floor - 1)
		get_viewport().set_input_as_handled()
	elif _open and event.keycode == KEY_ENTER:
		_on_floor_selected(_selected_floor)
		get_viewport().set_input_as_handled()


func _toggle_map() -> void:
	_open = not _open
	visible = _open
	if _open and _tower != null:
		_explored_floors = _tower.get_explored_floors()
		_refresh_rows()
	elif not _open:
		map_closed.emit()


func _select_floor(floor_id: int) -> void:
	_selected_floor = clampi(floor_id, 1, _floor_count())
	_refresh_rows()


func _on_floor_selected(floor_id: int) -> void:
	_selected_floor = floor_id
	floor_selected.emit(floor_id)
	if _tower != null and floor_id != _current_floor:
		_tower.start_travel(floor_id)
	_toggle_map()


func _refresh_rows() -> void:
	if _status_label == null:
		return
	if _tower != null:
		_current_floor = _get_player_floor()
	var lift_floor := _platform.get_display_floor() if _platform != null else -1
	var direction := _platform.get_direction_name().to_upper() if _platform != null else "IDLE"
	var player_side := _get_player_side()
	_status_label.text = "PLAYER %02d %s     LIFT %02d / %s" % [
		_current_floor, player_side, lift_floor, direction
	]
	for index in range(_rows.size()):
		var floor_id := _row_floor_ids[index]
		var button := _rows[index]
		var data := _floor_data(floor_id)
		var status := "UNEXPLORED"
		if floor_id == _current_floor:
			status = "PLAYER " + player_side
		elif floor_id == lift_floor:
			status = "PLATFORM"
		elif _explored_floors.has(floor_id):
			status = "EXPLORED"
		button.text = "FLOOR %02d   %-14s   %s" % [floor_id, MapAssetLibrary.floor_theme_name(data).to_upper(), status]
		button.modulate = Color(0.55, 0.9, 1.0) if floor_id == _selected_floor else Color.WHITE
	_last_refresh_key = "%d:%d:%s:%d" % [_current_floor, lift_floor, direction, _selected_floor]


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


func _get_player_floor() -> int:
	if _platform != null and _player != null and _platform.get_players().has(_player):
		return _platform.get_display_floor()
	return _tower.get_current_floor_id() if _tower != null else _current_floor


func _floor_count() -> int:
	if _tower != null and not _tower.tower_data.is_empty():
		return _tower.tower_data.size()
	return map_resource.total_floors if map_resource != null else 50


func _floor_data(floor_id: int) -> FloorData:
	if _tower == null or floor_id < 1 or floor_id > _tower.tower_data.size():
		return null
	var data := _tower.tower_data[floor_id - 1]
	return data.floor_data if data != null else null


func set_current_floor(floor_id: int) -> void:
	_current_floor = floor_id
	_selected_floor = floor_id
	_refresh_rows()


func mark_floor_explored(floor_id: int) -> void:
	if not _explored_floors.has(floor_id):
		_explored_floors.append(floor_id)
