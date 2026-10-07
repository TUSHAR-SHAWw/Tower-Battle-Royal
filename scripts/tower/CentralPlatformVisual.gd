class_name CentralPlatformVisual
extends Node2D

## Tile-sprite elevator deck built from the bundled Kenney industrial tiles.

@export var platform_radius: float = 128.0
@export var controller: CentralPlatformController

const DECK_WIDTH_TILES := 15
const TILE_SIZE := 18.0


func _ready() -> void:
	z_index = 3
	z_as_relative = false
	_build_deck()


func _build_deck() -> void:
	var half_width := float(DECK_WIDTH_TILES - 1) * TILE_SIZE * 0.5
	for index in range(DECK_WIDTH_TILES):
		var sprite := Sprite2D.new()
		sprite.name = "DeckTile_%02d" % index
		sprite.texture = MapAssetLibrary.tile_texture("tile_0007.png", true)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(float(index) * TILE_SIZE - half_width, TILE_SIZE * 0.5)
		add_child(sprite)

	var rail_y := TILE_SIZE * 1.5
	for side in [-1, 1]:
		var rail := Sprite2D.new()
		rail.name = "Rail_%d" % side
		rail.texture = MapAssetLibrary.tile_texture("tile_0000.png", true)
		rail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rail.position = Vector2(float(side) * (half_width - TILE_SIZE * 0.5), rail_y)
		add_child(rail)

	var signal_light := Sprite2D.new()
	signal_light.name = "DirectionLight"
	signal_light.texture = MapAssetLibrary.tile_texture("tile_0030.png")
	signal_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	signal_light.position = Vector2(0.0, TILE_SIZE * 1.5)
	signal_light.scale = Vector2.ONE * 0.65
	add_child(signal_light)

	if controller != null:
		controller.descent_speed_changed.connect(_on_speed_changed)
		_on_speed_changed(controller._speed)


func _on_speed_changed(speed: float) -> void:
	var indicator := get_node_or_null("DirectionLight") as Sprite2D
	if indicator != null:
		indicator.modulate = Color(0.35, 1.0, 0.55) if speed > 0.0 else Color(1.0, 0.45, 0.25)
