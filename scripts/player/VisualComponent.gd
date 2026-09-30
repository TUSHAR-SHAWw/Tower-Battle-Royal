class_name VisualComponent
extends Node2D

## Draws the flat-vector placeholder player.
##
## Purely presentational — no gameplay logic here. The body Color, outline and
## visor come from PlayerConfig so skins can replace this without touching code.

@export var config: PlayerConfig
@export var skin: SkinResource = null


func _draw() -> void:
	if config == null:
		return

	# Get colors from skin if equipped, otherwise from config
	var body_color: Color = config.body_color
	var accent_color: Color = config.accent_color
	var visor_color: Color = config.visor_color
	var outline_color: Color = config.outline_color
	var outline_width: float = config.outline_width
	var r = config.radius * 1.5  # Make player larger

	if skin != null:
		body_color = skin.body_color
		accent_color = skin.accent_color
		visor_color = skin.accent_color  # Use accent for visor
		if skin.has_glow:
			outline_color = skin.glow_color
			outline_width = config.outline_width * 2.0

	# Body circle - bright and visible
	draw_circle(Vector2.ZERO, r, body_color)
	# Thick white outline
	draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 1), outline_width * 2.0, true)
	# Inner accent ring
	draw_circle(Vector2.ZERO, r * 0.7, accent_color)

	# Visor (facing indicator) — a clear triangle in the facing direction.
	var player := get_parent()
	if player != null and player.has_node("MovementComponent"):
		var movement := player.get_node("MovementComponent") as MovementComponent
		if movement != null:
			var facing: Vector2 = movement.facing
			if not facing.is_zero_approx():
				var visor_end_pos: Vector2 = facing * (r * 1.2)
				# Draw triangle for facing direction
				var perp: Vector2 = Vector2(-facing.y, facing.x) * (r * 0.5)
				draw_polygon([
					Vector2.ZERO,
					visor_end_pos + perp,
					visor_end_pos - perp
				], [visor_color])

	# Glow effect
	if skin != null and skin.has_glow:
		draw_circle(Vector2.ZERO, r + 8.0, skin.glow_color, 3.0, true)

	# Debug: draw small center dot
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 1))


func apply_skin(skin_resource: SkinResource) -> void:
	skin = skin_resource
	queue_redraw()


func debug_line() -> String:
	return "Visual"