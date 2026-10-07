class_name MapAssetLibrary
extends RefCounted

const BASE_TILE_ROOT := "res://assets/kenney_pixel-platformer/Tiles/"
const INDUSTRIAL_TILE_ROOT := "res://assets/kenney_pixel-platformer-industrial-expansion/Tiles/"

const ITEM_ICONS := {
	&"health_pack": "tile_0030.png",
	&"adrenaline": "tile_0044.png",
	&"knife_base": "tile_0055.png",
}


static func tile_texture(tile_name: String, industrial: bool = false) -> Texture2D:
	var root := INDUSTRIAL_TILE_ROOT if industrial else BASE_TILE_ROOT
	return load(root + tile_name) as Texture2D


static func item_texture(item: ItemResource) -> Texture2D:
	if item == null:
		return tile_texture("tile_0030.png")
	if item.icon_texture != null:
		return item.icon_texture
	if item.item_id == &"ar_base":
		return tile_texture("tile_0073.png", true)
	var tile_name: String = ITEM_ICONS.get(item.item_id, "tile_0030.png")
	return tile_texture(tile_name)


static func floor_theme_color(floor_data: FloorData) -> Color:
	if floor_data != null and floor_data.theme != null:
		return floor_data.theme.ambient_color
	if floor_data != null:
		return floor_data.ambient_color
	return Color(0.12, 0.10, 0.08, 1.0)


static func floor_backdrop_tint(floor_data: FloorData) -> Color:
	var theme_name := floor_data.theme_name.to_lower() if floor_data != null else "mountain"
	match theme_name:
		"desert":
			return Color(0.44, 0.34, 0.22, 1.0)
		"volcano":
			return Color(0.42, 0.20, 0.16, 1.0)
		"ice":
			return Color(0.30, 0.43, 0.56, 1.0)
		"water":
			return Color(0.26, 0.42, 0.52, 1.0)
		_:
			return Color(0.37, 0.40, 0.43, 1.0)


static func floor_theme_name(floor_data: FloorData) -> String:
	if floor_data != null and floor_data.theme != null:
		return floor_data.theme.display_name
	if floor_data != null:
		return floor_data.display_name
	return "Unknown"
