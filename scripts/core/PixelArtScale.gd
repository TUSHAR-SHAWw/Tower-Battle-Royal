class_name PixelArtScale
extends RefCounted

## Shared scale contract for 8px source art rendered at 3x on a 426x240 canvas.
const LOGICAL_VIEWPORT := Vector2i(426, 240)
const DISPLAY_SCALE := 3.0
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const CAMERA_ZOOM := 13.0 / 60.0
const TILE_SOURCE_SIZE := 8
const TILE_SCREEN_SIZE := 24.0
const UI_SCALE := 1.0 / DISPLAY_SCALE


## Renders each 8px source pixel as one logical pixel before the 3x upscale.
static func tilemap_scale() -> Vector2:
	return Vector2.ONE * (TILE_SCREEN_SIZE / (
		float(TILE_SOURCE_SIZE) * DISPLAY_SCALE * CAMERA_ZOOM
	))


## Fits existing 1280x720 Control layouts into the low-resolution viewport.
static func fit_ui_root(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = DESIGN_SIZE
	control.scale = Vector2.ONE * UI_SCALE


## Creates the shared UI coordinate space for both scene-backed and runtime UI.
static func ensure_ui_root(parent: Node, node_name: StringName = &"PixelArtCanvas") -> Control:
	var root := parent.get_node_or_null(NodePath(node_name)) as Control
	if root == null:
		root = Control.new()
		root.name = String(node_name)
		parent.add_child(root)
	fit_ui_root(root)
	return root
