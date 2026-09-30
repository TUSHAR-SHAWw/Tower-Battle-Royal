## Draws the floor background, grid, and boundaries.
##
## Purely presentational — no collision logic here. The slab and the shaft are
## drawn as solid blocks so the room reads as a storey of a building: an open
## space with a thick divider under it and a hole punched through the middle.

extends Node2D
class_name FloorVisual

@export var floor_data: FloorData

var _label_font: Font = null


func _ready() -> void:
	# Try to get a default font for the label
	_label_font = ThemeDB.get_default_theme().get_font("font", "Label")
	if _label_font == null:
		# Fallback: create a simple dynamic font
		_label_font = FontFile.new()


func _draw() -> void:
	if floor_data == null:
		return

	var bounds := floor_data.bounds
	var shaft_half := maxf(floor_data.shaft_width, 0.0) * 0.5
	var slab_height := float(FloorTileLayout.SLAB_ROWS * FloorTileLayout.TILE)
	var slab_top := bounds.position.y + bounds.size.y - slab_height

	# The room itself: an open space above the slab.
	var room := Rect2(bounds.position, Vector2(bounds.size.x, bounds.size.y - slab_height))
	draw_rect(room, floor_data.ambient_color)

	# The slab, drawn as two blocks either side of the shaft so the hole is
	# visible rather than implied.
	var slab_color := floor_data.ambient_color.darkened(0.35)
	var left_w := (bounds.size.x * 0.5) - shaft_half
	if left_w > 0.0:
		draw_rect(Rect2(Vector2(bounds.position.x, slab_top), Vector2(left_w, slab_height)), slab_color)
		draw_rect(Rect2(Vector2(bounds.position.x + bounds.size.x * 0.5 + shaft_half, slab_top),
			Vector2(left_w, slab_height)), slab_color)
	else:
		# Shaft wider than the floor: nothing solid is left, which the validator
		# rejects, but draw the slab anyway so the mistake is visible.
		draw_rect(Rect2(Vector2(bounds.position.x, slab_top), Vector2(bounds.size.x, slab_height)), slab_color)

	# Grid lines over the open room only — a grid across the slab muddies it.
	var grid_color := Color(1.0, 1.0, 1.0, 0.10)
	var grid_size := 128.0
	var start_x := int(floor(bounds.position.x / grid_size)) * int(grid_size)
	var start_y := int(floor(bounds.position.y / grid_size)) * int(grid_size)
	for x in range(start_x, int(bounds.position.x + bounds.size.x), int(grid_size)):
		draw_line(Vector2(x, bounds.position.y), Vector2(x, slab_top), grid_color)
	for y in range(start_y, int(slab_top), int(grid_size)):
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.position.x + bounds.size.x, y), grid_color)

	# Shaft guides: two vertical lines marking the drop, so the hole is readable
	# from across the room instead of being a surprise.
	if shaft_half > 0.0:
		var center_x := bounds.position.x + bounds.size.x * 0.5
		var guide := Color(0.2, 0.8, 1.0, 0.35)
		var guide_h := bounds.size.y - slab_height
		draw_line(Vector2(center_x - shaft_half, slab_top - guide_h), Vector2(center_x - shaft_half, slab_top), guide, 2.0)
		draw_line(Vector2(center_x + shaft_half, slab_top - guide_h), Vector2(center_x + shaft_half, slab_top), guide, 2.0)

	# Boundary outline (thick and bright)
	var outline_color := Color(1.0, 1.0, 1.0, 0.8)
	draw_rect(bounds, outline_color, false, 6.0)

	# Corner markers for orientation
	var corner_size := 40.0
	draw_line(Vector2(bounds.position.x, bounds.position.y), Vector2(bounds.position.x + corner_size, bounds.position.y), Color(1, 1, 0, 1), 4.0)
	draw_line(Vector2(bounds.position.x, bounds.position.y), Vector2(bounds.position.x, bounds.position.y + corner_size), Color(1, 1, 0, 1), 4.0)
