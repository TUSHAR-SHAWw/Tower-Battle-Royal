class_name FloorTheme
extends Resource

## A data-driven theme for one floor storey — palette, slab thickness, wall style,
## prop set, and lighting colour. Keeps the art direction configurable instead of
## baked into the visual script.

@export_group("Identity")
@export var theme_name: String = "base"
@export var display_name: String = "Floor Theme"

@export_group("Palette")
@export var wall_color: Color = Color(0.26, 0.19, 0.14, 1.0)
@export var slab_top_color: Color = Color(0.53, 0.31, 0.16, 1.0)
@export var slab_core_color: Color = Color(0.31, 0.16, 0.11, 1.0)
@export var slab_rim_color: Color = Color(0.94, 0.68, 0.27, 1.0)

@export_group("Walls & Frame")
@export var slab_thickness_tiles: int = 3
@export var wall_thickness: float = 48.0
@export var wall_pattern: String = "wood"

@export_group("Lighting")
@export var light_color: Color = Color(0.95, 0.82, 0.45, 1.0)
@export var light_pool_radius: float = 280.0
@export var ambient_color: Color = Color(0.15, 0.10, 0.08, 1.0)

@export_group("Props & Decor")
@export var prop_types: PackedStringArray = ["desk", "cabinet", "plant", "clock", "lamp"]
@export var prop_count: int = 6
@export var prop_size: float = 42.0

@export_group("Shaft & Loot")
@export var loot_items_on_lip: PackedStringArray = ["coin_10", "health_pack"]
@export var loot_marker_size: float = 24.0


func validate() -> Array[String]:
	var problems: Array[String] = []
	if slab_thickness_tiles < 1:
		problems.append("slab_thickness_tiles must be >= 1 (got %d)" % slab_thickness_tiles)
	if wall_thickness <= 0.0:
		problems.append("wall_thickness must be > 0 (got %.1f)" % wall_thickness)
	if prop_size <= 0.0:
		problems.append("prop_size must be > 0 (got %.1f)" % prop_size)
	if prop_count < 0:
		problems.append("prop_count must be >= 0 (got %d)" % prop_count)
	return problems
