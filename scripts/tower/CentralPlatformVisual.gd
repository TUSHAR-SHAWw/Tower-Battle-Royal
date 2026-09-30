class_name CentralPlatformVisual
extends Node2D

## Visual representation of the central platform.
## Draws the descending platform with a distinctive marker.

@export var platform_radius: float = 128.0
@export var controller: CentralPlatformController


func _draw() -> void:
	if controller == null:
		return

	var state := controller.get_state()
	var color := Color(1.0, 0.9, 0.3, 0.8)
	if state == &"paused":
		color = Color(1.0, 1.0, 0.3, 1.0)
	elif state == &"arrived":
		color = Color(0.3, 1.0, 0.8, 0.9)

	var pulse := sin(OS.get_ticks_msec() / 400.0) * 0.3 + 0.7
	var radius := platform_radius * (0.9 + pulse * 0.1)

	draw_circle(Vector2.ZERO, radius, color, true, 0, true)
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.8), false, 4.0)

	# Downward arrow indicator
	var arrow_size := 24.0
	draw_line(Vector2(-arrow_size, -arrow_size), Vector2(0, -arrow_size * 2 + radius), Color(0, 0, 0, 0.8), 2.0)
	draw_line(Vector2(arrow_size, -arrow_size), Vector2(0, -arrow_size * 2 + radius), Color(0, 0, 0, 0.8), 2.0)
	draw_line(Vector2(0, -arrow_size * 2 + radius), Vector2(0, -arrow_size + radius), Color(0, 0, 0, 0.8), 2.0)


func _process(_delta: float) -> void:
	queue_redraw()
