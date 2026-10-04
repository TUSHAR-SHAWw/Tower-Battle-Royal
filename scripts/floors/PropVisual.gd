class_name PropVisual
extends Node2D

## A single flat-vector prop drawn in code: a rounded rectangle with a bold dark
## outline and a warm face colour — exactly the reference art (`floor_art_example.jpg`).
## Props are sized by `prop_size_points` (world px) and coloured by the floor theme,
## so a volcano floor's props look like red-brick crates while an ice floor's props
## look like crystal slabs — no downloaded asset needed.

@export var theme: FloorTheme = null

@export var prop_size_points: Vector2 = Vector2(42.0, 42.0)
@export var prop_face: Color = Color(0.45, 0.30, 0.18, 1.0)
@export var prop_outline: Color = Color(0.10, 0.08, 0.05, 1.0)
@export var prop_type: String = "desk"  # desk, cabinet, lamp, clock, plant

## The reference art uses a 2.5D bevel effect: a darker bottom lip that makes the
## prop read as a solid block rather than a flat card.
@export var prop_bevel_dark_ratio: float = 0.65


func _draw() -> void:
	if prop_size_points == Vector2.ZERO:
		return
	var w := prop_size_points.x
	var h := prop_size_points.y

	# Theme override: the theme's prop colour takes precedence so the same prop
	# class looks different on a volcano floor (red/black) vs an ice floor (white/blue).
	var face_color := prop_face
	var outline_color := prop_outline
	if theme != null:
		face_color = theme.slab_top_color.darkened(0.15)
		outline_color = theme.wall_color.darkened(0.6)

	# Main face — warm wood/concrete tone.
	var face_gradient := Color(face_color.r, face_color.g, face_color.b, face_color.a)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), face_gradient, true)

	# Thick dark outline — the bold-stroke look of the reference art.
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), outline_color, false, 2.5)

	# Bottom bevel / lip — a darker strip at the very bottom of the prop that makes
	# it read as a 3D block sitting on the floor rather than a flat card floating.
	var bevel_h: float = h * 0.12
	draw_rect(
		Rect2(Vector2(0.0, h - bevel_h), Vector2(w, bevel_h)),
		face_color.darkened(prop_bevel_dark_ratio),
		true
	)
