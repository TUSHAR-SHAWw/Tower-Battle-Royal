extends Node2D
class_name FloorVisual

## Draws the floor background, grid, and boundaries using Control nodes
## (not _draw() code) so they can be edited in the Godot editor.
## The slab and shaft are drawn as real panel nodes with theme-aware colours.

@export var floor_data: FloorData
@export var theme: FloorTheme = null

@onready var _bg: ColorRect = ColorRect.new()
@onready var _slab_left: ColorRect = ColorRect.new()
@onready var _slab_right: ColorRect = ColorRect.new()
@onready var _guide_left: ColorRect = ColorRect.new()
@onready var _guide_right: ColorRect = ColorRect.new()

func _ready() -> void:
	if theme == null:
		theme = load("res://resources/floors/theme_base.tres") as FloorTheme
	if floor_data == null:
		return
	# Create child ColorRects at the correct positions instead of drawing

func _draw() -> void:
	# No longer drawing; nodes are children
	pass
