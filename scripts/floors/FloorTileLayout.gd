class_name FloorTileLayout
extends RefCounted

## Generates a placeholder tile layout for a floor.
##
## Purpose: give every floor a real, walkable side-view surface immediately
## without hand-authoring tilemaps, while keeping the result *editable* — the
## TileMapLayer nodes are normal scene nodes, so you can open a floor in the
## editor, paint over these placeholder tiles, and save. Regeneration only
## happens when a layout is missing, so hand edits survive.
##
## Shape of a floor (all floors are the same size — see FloorData.DEFAULT_BOUNDS):
##
##     ┌──────────────────────────────────────────────┐  y = bounds top
##     │  open room — the slab above is the ceiling    │
##     │                                               │
##     │                  ╷ shaft ╷                    │
##     │                  ╵       ╵                    │
##     ├══════════════════╡       ╞════════════════════┤  slab, SLAB_ROWS thick
##     │                  ╰───────╯                    │
##     └──────────────────────────────────────────────┘  y = bounds bottom
##
## The slab is the floor the player stands on. The shaft is a gap cut through it
## in the centre: the descending platform rides down it, loot spawns on its lip,
## and falling in drops you a floor. There is deliberately NO per-floor ceiling —
## the slab of the floor above is the ceiling of this one, which is what makes the
## tower read as stacked storeys instead of floating platforms.
##
## Also lays out a few interior platforms so a room is not an empty box to fight
## in: four ledges at staggered heights give vertical play without walling the
## room off. They never cross the shaft column, so the shaft stays a clear drop.

const TILE := 18

## Thickness of the slab between two floors, in tiles. Three tiles = 54 px: thick
## enough to read as a storey divider and to make the shaft look like a shaft.
const SLAB_ROWS := 3

## Interior ledges per side. Keep this even so both sides get the same count.
const LEDGES_PER_SIDE := 2

## Ledge width in tiles.
const LEDGE_TILES := 14


## Populates `ground` (solid, collides) and `decor` (no collision) for one floor.
##
## `shaft_width` is the pixel width of the central opening; pass 0 for a sealed
## slab. `theme_source` picks which atlas source the tiles come from so adjacent
## floors do not look identical.
static func populate(ground: TileMapLayer, decor: TileMapLayer, tile_set: TileSet,
		bounds: Rect2, seed_value: int, theme_source: int, shaft_width: float = 640.0) -> void:
	if tile_set == null or ground == null or decor == null:
		return

	ground.tile_set = tile_set
	decor.tile_set = tile_set
	ground.clear()
	decor.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Work in whole tiles so the layout lines up with the tileset grid.
	var origin_cell := Vector2i(
		int(floor(bounds.position.x / TILE)),
		int(floor(bounds.position.y / TILE))
	)
	var size_cell := Vector2i(
		maxi(1, int(ceil(bounds.size.x / TILE))),
		maxi(1, int(ceil(bounds.size.y / TILE)))
	)

	# The slab occupies the bottom SLAB_ROWS rows of the bounds.
	var slab_top := origin_cell.y + size_cell.y - SLAB_ROWS
	var left := origin_cell.x
	var right := origin_cell.x + size_cell.x - 1

	# Shaft column, in whole tiles, centred on the floor.
	# A width of 0 means "sealed" — used for the bottom storey, where an open
	# shaft would drop the player out of the world.
	var shaft_cells := int(round(shaft_width / float(TILE)))
	var sealed := shaft_cells <= 0
	var center_cell := origin_cell.x + size_cell.x / 2
	var shaft_left := center_cell - shaft_cells / 2
	var shaft_right := shaft_left + shaft_cells - 1

	var ground_coords := _ground_row_coords(rng)
	var decor_coords := _decor_coords(rng)

	# --- Slab ---------------------------------------------------------------
	# Solid across the full width, with the shaft left open. Every row of the
	# slab is filled so the underside is solid too: the floor above's slab is
	# this floor's ceiling, and vice versa.
	for x in range(left, right + 1):
		if _in_shaft(x, shaft_left, shaft_right):
			continue
		for row in range(SLAB_ROWS):
			ground.set_cell(Vector2i(x, slab_top + row), theme_source, ground_coords)

	# --- Shaft lip ----------------------------------------------------------
	# A single row of solid tiles along each wall of the shaft, so a player
	# standing at the edge has something to stand on and cannot clip into the
	# gap at the exact corner. Skipped when sealed: there is no gap to edge.
	if not sealed:
		for x in [shaft_left - 1, shaft_right + 1]:
			if x >= left and x <= right:
				ground.set_cell(Vector2i(x, slab_top), theme_source, ground_coords)

	# --- Interior ledges ----------------------------------------------------
	# Staggered platforms either side of the shaft. They give the room vertical
	# play without blocking movement, and never overlap the shaft column.
	_add_ledges(ground, rng, origin_cell, size_cell, slab_top, shaft_left, shaft_right,
		theme_source, ground_coords)

	# --- Decoration ---------------------------------------------------------
	# Sparse background scenery on the decor source, which has no collision, so
	# scenery never becomes an invisible platform.
	var room_top := origin_cell.y + 1
	for x in range(left + 1, right):
		for y in range(room_top, slab_top):
			if rng.randf() > 0.10:
				continue
			decor.set_cell(Vector2i(x, y), TowerTileSetBuilder.SOURCE_DECOR, decor_coords)


## Adds staggered ledges on both sides of the room.
static func _add_ledges(ground: TileMapLayer, rng: RandomNumberGenerator,
		origin_cell: Vector2i, size_cell: Vector2i, slab_top: int,
		shaft_left: int, shaft_right: int, theme_source: int, coords: Vector2i) -> void:
	var room_height := slab_top - origin_cell.y
	if room_height < LEDGES_PER_SIDE * 4:
		return  # Room too short to place ledges without crowding it.

	var left := origin_cell.x
	var right := origin_cell.x + size_cell.x - 1

	for i in range(LEDGES_PER_SIDE):
		# Spread the ledges through the middle of the room, never right at the
		# slab or the top edge.
		var t := float(i + 1) / float(LEDGES_PER_SIDE + 1)
		var row := origin_cell.y + int(room_height * t)
		# Alternate sides so the ledges read as a climbable zig-zag.
		var on_left := i % 2 == 0

		var start_x: int
		var end_x: int
		if on_left:
			start_x = left + 1 + rng.randi_range(0, 6)
			end_x = start_x + LEDGE_TILES - 1
			end_x = mini(end_x, shaft_left - 2)
		else:
			end_x = right - 1 - rng.randi_range(0, 6)
			start_x = end_x - LEDGE_TILES + 1
			start_x = maxi(start_x, shaft_right + 2)

		if end_x <= start_x:
			continue
		for x in range(start_x, end_x + 1):
			ground.set_cell(Vector2i(x, row), theme_source, coords)


static func _in_shaft(x: int, shaft_left: int, shaft_right: int) -> bool:
	return x >= shaft_left and x <= shaft_right


## Picks a tile from the lower band of the sheet, where Kenney keeps its solid
## ground/brick blocks, so the surface looks coherent.
static func _ground_row_coords(rng: RandomNumberGenerator) -> Vector2i:
	var candidates := PackedVector2Array([
		Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5),
		Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	])
	return candidates[rng.randi() % candidates.size()]


static func _decor_coords(rng: RandomNumberGenerator) -> Vector2i:
	var candidates := PackedVector2Array([
		Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
		Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2),
	])
	return candidates[rng.randi() % candidates.size()]
