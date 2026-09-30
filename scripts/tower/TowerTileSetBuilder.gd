class_name TowerTileSetBuilder
extends RefCounted

## Builds the tower TileSet from the Kenney pixel-platformer packs in `assets/`.
##
## Both packs use 18x18 px tiles, so each pack becomes one atlas source inside a
## single TileSet. Keeping construction in code rather than a hand-authored .tres
## means the art can be swapped or re-pointed later by editing the constants at
## the top of this file, instead of hand-editing thousands of tile entries.
##
## Source packs (grouped as "base" and "industrial" so floors can pick a theme):
##   base        assets/kenney_pixel-platformer/Tilemap/tilemap.png             (grass/dirt/stone)
##   industrial  assets/kenney_pixel-platformer-industrial-expansion/Tilemap/tilemap.png
##
## Individual loose tiles are also available under each pack's `Tiles/` folder if
## you want to swap in custom art per floor later.

const TILE_SIZE := Vector2i(18, 18)

## Atlas source ids. Keep these stable — floors and saved TileMapLayer data
## reference cells as (source_id, atlas_coords).
const SOURCE_BASE := 0
const SOURCE_INDUSTRIAL := 1
## Background decoration. Uses the base art but has NO collision, so scenery
## never becomes an invisible platform.
const SOURCE_DECOR := 2

const BASE_SHEET := "res://assets/kenney_pixel-platformer/Tilemap/tilemap.png"
const INDUSTRIAL_SHEET := "res://assets/kenney_pixel-platformer-industrial-expansion/Tilemap/tilemap.png"

## Tile group name for anything that blocks movement.
const SOLID_GROUP := "solid"


## Creates the TileSet with both packs registered as atlas sources.
static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	# Collision is addressed by layer id, so the layer must exist before any
	# tile can add a polygon to it.
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, PhysicsLayers.WORLD)
	_add_source(tile_set, SOURCE_BASE, BASE_SHEET)
	_add_source(tile_set, SOURCE_INDUSTRIAL, INDUSTRIAL_SHEET)
	# Decor reuses the base art with collision disabled.
	_add_source(tile_set, SOURCE_DECOR, BASE_SHEET, false)
	return tile_set


## Registers one uniform-grid sheet as an atlas source.
##
## `solid` controls whether each cell gets a full-cell collision polygon. Decor
## sources pass false so scenery stays walk-through.
static func _add_source(tile_set: TileSet, source_id: int, sheet_path: String, solid: bool = true) -> void:
	if not ResourceLoader.exists(sheet_path):
		push_warning("TowerTileSetBuilder: tilesheet missing: %s" % sheet_path)
		return

	var texture := load(sheet_path) as Texture2D
	if texture == null:
		push_warning("TowerTileSetBuilder: could not load texture: %s" % sheet_path)
		return

	var columns := int(texture.get_width() / float(TILE_SIZE.x))
	var rows := int(texture.get_height() / float(TILE_SIZE.y))
	if columns <= 0 or rows <= 0:
		push_warning("TowerTileSetBuilder: %s is not a whole number of %s tiles"
			% [sheet_path, str(TILE_SIZE)])
		return

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	for row in rows:
		for column in columns:
			source.create_tile(Vector2i(column, row))

	# The source must belong to the TileSet before its tile data is configured,
	# otherwise the data has no access to the TileSet's physics layers.
	tile_set.add_source(source, source_id)

	for row in rows:
		for column in columns:
			var coords := Vector2i(column, row)
			var data := source.get_tile_data(coords, 0)
			if not solid:
				continue
			# Allocate a collision polygon on layer 0, then define its points.
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, _full_cell_points())


## The four corners of a tile cell, as a solid quad.
static func _full_cell_points() -> PackedVector2Array:
	var w := float(TILE_SIZE.x)
	var h := float(TILE_SIZE.y)
	return PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(w, 0.0),
		Vector2(w, h),
		Vector2(0.0, h),
	])
