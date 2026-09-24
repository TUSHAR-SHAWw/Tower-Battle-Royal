class_name VisualComponent
extends Node2D

## Draws the flat-vector placeholder player.
##
## Purely presentational — no gameplay logic here. The body Color, outline and
## visor come from PlayerConfig so skins can replace this without touching code.

@export var config: PlayerConfig


func _draw() -> void:
	if config == null:
		return

	var r := config.radius

	# Body circle.
	draw_circle(Vector2.ZERO, r, config.body_color)
	# Outline.
	draw_circle(Vector2.ZERO, r, config.outline_color, config.outline_width, true)

	# Visor (facing indicator) — a small line in the facing direction.
	# We need the player's facing; ask the parent Player for its MovementComponent.
	var player := get_parent()
	if player != null and player.has_node("MovementComponent"):
		var movement := player.get_node("MovementComponent") as MovementComponent
		if movement != null:
			var facing := movement.facing
			var visor_end_pos := facing * (r * 0.8)
			draw_line(Vector2.ZERO, visor_end_pos, config.visor_color, config.outline_width)


func debug_line() -> String:
	return "Visual"