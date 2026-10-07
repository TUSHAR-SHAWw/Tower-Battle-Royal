extends Node2D
class_name FloorVisual

@export var floor_data: FloorData
@export var theme: FloorTheme

var _backdrop: TextureRect
var _horizon: ColorRect
var _left_pillar: ColorRect
var _right_pillar: ColorRect


func _ready() -> void:
	_create_visual_nodes()
	if floor_data != null:
		configure_floor(floor_data, theme)


func configure_floor(data: FloorData, floor_theme: FloorTheme = null) -> void:
	floor_data = data
	theme = floor_theme if floor_theme != null else (data.theme if data != null else null)
	if not is_node_ready():
		return
	_create_visual_nodes()
	if floor_data == null:
		return
	var bounds := floor_data.bounds
	var ambient := MapAssetLibrary.floor_theme_color(floor_data)
	var wall := theme.wall_color if theme != null else ambient.lightened(0.3)
	var rim := theme.slab_rim_color if theme != null else ambient.lightened(0.5)
	_backdrop.position = bounds.position
	_backdrop.size = bounds.size / 8.0
	_backdrop.scale = Vector2.ONE * 8.0
	_backdrop.modulate = MapAssetLibrary.floor_backdrop_tint(floor_data)
	_horizon.position = Vector2(bounds.position.x, bounds.position.y + bounds.size.y * 0.22)
	_horizon.size = Vector2(bounds.size.x, 10.0)
	_horizon.color = rim
	_horizon.modulate.a = 0.34
	var center_x := bounds.position.x + bounds.size.x * 0.5
	_left_pillar.position = Vector2(center_x - 310.0, bounds.position.y + 84.0)
	_right_pillar.position = Vector2(center_x + 286.0, bounds.position.y + 84.0)
	_left_pillar.size = Vector2(24.0, bounds.size.y * 0.34)
	_right_pillar.size = Vector2(24.0, bounds.size.y * 0.34)
	_left_pillar.color = wall.lightened(0.12)
	_right_pillar.color = wall.lightened(0.12)
	_left_pillar.modulate.a = 0.6
	_right_pillar.modulate.a = 0.6


func _create_visual_nodes() -> void:
	if _backdrop != null:
		return
	_backdrop = TextureRect.new()
	_backdrop.name = "ThemeBackdrop"
	_backdrop.texture = MapAssetLibrary.tile_texture("tile_0001.png", true)
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_TILE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = -10
	_backdrop.z_as_relative = false
	add_child(_backdrop)
	_horizon = _make_rect("ThemeHorizon", -9)
	_left_pillar = _make_rect("ThemePillarLeft", -8)
	_right_pillar = _make_rect("ThemePillarRight", -8)


func _make_rect(node_name: String, draw_order: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = draw_order
	rect.z_as_relative = false
	add_child(rect)
	return rect
