extends Node2D
class_name FloorVisual

## Draws the floor background, grid, and boundaries.
## Purely presentational — no collision logic here.

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
	var color := floor_data.ambient_color
	
	# Floor background
	draw_rect(bounds, color)
	
	# Grid lines (subtle)
	var grid_color := Color(1.0, 1.0, 1.0, 0.03)
	var grid_size := 128.0
	
	var start_x := int(floor(bounds.position.x / grid_size)) * int(grid_size)
	var start_y := int(floor(bounds.position.y / grid_size)) * int(grid_size)
	var end_x := int(bounds.position.x + bounds.size.x)
	var end_y := int(bounds.position.y + bounds.size.y)
	
	for x in range(start_x, end_x, int(grid_size)):
		draw_line(Vector2(x, bounds.position.y), Vector2(x, end_y), grid_color)
	for y in range(start_y, end_y, int(grid_size)):
		draw_line(Vector2(bounds.position.x, y), Vector2(end_x, y), grid_color)
	
	# Boundary outline
	var outline_color := Color(1.0, 1.0, 1.0, 0.3)
	draw_rect(bounds, outline_color, false, 3.0)
	
	# Floor label (disabled due to draw_string API issues in headless)
	# if _label_font != null:
	# 	var label_pos := bounds.position + Vector2(20, 30)
	# 	draw_string(_label_font, label_pos, "FLOOR %d" % floor_data.floor_id, Color(1.0, 1.0, 1.0, 0.5))