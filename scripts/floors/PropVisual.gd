class_name PropVisual
extends Node2D

@export var theme: FloorTheme
@export var prop_size_points: Vector2 = Vector2(42.0, 42.0)
@export var prop_face: Color = Color(0.45, 0.30, 0.18, 1.0)
@export var prop_outline: Color = Color(0.10, 0.08, 0.05, 1.0)
@export var prop_type: String = "desk"

const PROP_TILES := {
	"desk": ["tile_0001.png", true],
	"cabinet": ["tile_0031.png", false],
	"lamp": ["tile_0073.png", true],
	"clock": ["tile_0030.png", false],
	"plant": ["tile_0000.png", false],
}


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "PropSprite"
	var tile: Array = PROP_TILES.get(prop_type, PROP_TILES["cabinet"])
	sprite.texture = MapAssetLibrary.tile_texture(tile[0], tile[1])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size := sprite.texture.get_size() if sprite.texture != null else Vector2.ONE
	sprite.scale = Vector2(
		prop_size_points.x / texture_size.x,
		prop_size_points.y / texture_size.y
	)
	sprite.modulate = theme.slab_top_color if theme != null else prop_face
	add_child(sprite)
