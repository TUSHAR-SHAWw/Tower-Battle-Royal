class_name CameraComponent
extends Node

## Handles the floor-clamped camera with optional aim lead.
##
## The camera follows the player with smoothing and can lean toward the aim
## direction. It never leaves the current floor bounds (M2 provides those bounds).

@export var camera: Camera2D
@export var config: PlayerConfig

var _target_pos: Vector2 = Vector2.ZERO
var _floor_bounds: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)


func _ready() -> void:
	if camera == null:
		push_error("CameraComponent: no Camera2D assigned.")
	if config == null:
		push_error("CameraComponent: no PlayerConfig assigned.")


func set_floor_bounds(bounds: Rect2) -> void:
	_floor_bounds = bounds


## Called once per physics frame from the active movement state.
func update(delta: float) -> void:
	if camera == null or config == null:
		return

	# Base position is the player's global position.
	var player_body := camera.get_parent()
	if player_body != null:
		_target_pos = player_body.global_position
	else:
		_target_pos = camera.global_position

	# Add aim lead if configured.
	if config.camera_lead_pixels > 0.0 and camera.has_node(".."):
		var player_node := camera.get_node("..")
		if player_node != null and player_node.has_method("get_aim_direction"):
			var aim_dir: Vector2 = player_node.get_aim_direction()
			if not aim_dir.is_zero_approx():
				_target_pos += aim_dir * config.camera_lead_pixels

	# Clamp to floor bounds (camera center must stay inside).
	var half := camera.get_viewport_rect().size * 0.5 / config.camera_zoom
	var min_x := _floor_bounds.position.x + half.x
	var max_x := _floor_bounds.position.x + _floor_bounds.size.x - half.x
	var min_y := _floor_bounds.position.y + half.y
	var max_y := _floor_bounds.position.y + _floor_bounds.size.y - half.y

	_target_pos.x = clampf(_target_pos.x, min_x, max_x)
	_target_pos.y = clampf(_target_pos.y, min_y, max_y)

	# Smooth toward target.
	camera.global_position = camera.global_position.lerp(_target_pos, config.camera_smoothing_speed * delta)

	# Apply zoom.
	camera.zoom = Vector2.ONE * config.camera_zoom


func debug_line() -> String:
	return "cam %.0f,%.0f" % [_target_pos.x, _target_pos.y]