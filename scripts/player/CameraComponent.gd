class_name CameraComponent
extends Node

## Framing rig for a side-view platformer.
##
## Responsibilities are split deliberately: this component decides *what the
## frame should contain*, and the Camera2D underneath only carries zoom, limits
## and offset effects. That split is what lets feedback (shake, recoil) sit on
## `Camera2D.offset` without disturbing the framing.
##
## What it does, and why each part exists:
##
## * **Dead zone** — a box around a remembered anchor. Inside it, the player moves
##   and the frame does not. This is what stops the screen answering every small
##   correction while lining up a jump.
## * **Look-ahead on committed velocity** — running right should show what is to
##   the right, but a mouse twitch must not throw the frame. The lead only engages
##   above `look_ahead_commit_speed` and eases in over `look_ahead_speed`.
## * **Vertical dead zone larger than a jump** — a routine jump goes up and comes
##   back down to the same ground, so it must not move the frame. Only a genuine
##   climb crosses the boundary. Its distances are expressed in the scaled match
##   gameplay world units.
## * **Ground re-centring** — once the player lands, the remembered height eases
##   back to theirs, so a staircase of jumps does not leave the anchor behind.
## * **Fall look-ahead** — a long drop slides the frame down in proportion to fall
##   speed, so the landing is on screen before you get there.
## * **Scrolling framing** — the 426x240 logical canvas and adjusted camera zoom
##   preserve the previous 1280x720 world view while allowing 8px source tiles
##   to render at 24 screen pixels.
##
## All values are `@export` so they can be tuned without touching code, and every
## default here is a PROTOTYPE DEFAULT, not a balance decision.

@export var camera: Camera2D
@export var config: PlayerConfig

@export_group("Framing")
## Width / height of the still zone around the anchor, in gameplay world units.
##
## The vertical zone clears the configured held jump without hiding a sustained
## climb; horizontally it swallows small corrections before a jump.
@export var dead_zone: Vector2 = Vector2(110.0, 600.0)

## How fast the rig catches up to its target. Higher is snappier. Applied as
## 1 - exp(-speed * delta) so the feel is identical at 60 and 144 fps.
@export var follow_speed: float = 6.0

@export_group("Look Ahead")
## How far the frame leads in the direction of travel, in gameplay world units.
@export var look_ahead_distance: float = 150.0
## When > 0, overrides the lead distance with PlayerConfig.camera_lead_pixels at
## runtime so one config resource drives both the rig and the exported values.
@export var use_config_lead: bool = true
## Below this horizontal speed the movement counts as a correction, not a
## commitment, and the lead does not engage. Walk speed is 220, so 40 means a
## nudge never registers but a real walk does.
@export var look_ahead_commit_speed: float = 40.0
## How patient the lead is. Noticeably slower than follow_speed so a direction
## change opens up the view over about half a second instead of snapping.
@export var look_ahead_speed: float = 2.2

@export_group("Vertical")
## Downward speed (px/s) treated as "falling at full tilt" for the fall reveal.
@export var fall_speed_reference: float = 900.0
## How far the frame slides down at full falling speed.
@export var fall_look_distance: float = 150.0
## How fast the remembered ground height re-centres on the player once landed.
@export var ground_recenter_speed: float = 1.5
## Constant lift so the player sits slightly below centre, leaving headroom.
@export var vertical_offset: float = 0.0

@export_group("Limits")
## How far outside the floor bounds the camera may look. Small: the floor edges
## are the walls of the room and the frame should not drift past them.
@export var bounds_overshoot: float = 0.0

@export_group("Effects")
@export var shake_decay: float = 6.0
@export var punch_recover: float = 8.0

var _anchor: Vector2 = Vector2.ZERO
var _look_ahead: float = 0.0
var _fall_percentage: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_dir: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_frequency: float = 20.0
var _punch: Vector2 = Vector2.ZERO
var _floor_bounds: Rect2 = FloorData.DEFAULT_BOUNDS
var _needs_initial_snap: bool = true
var _last_debug_frame: int = -1


func _ready() -> void:
	if camera == null:
		var parent := get_parent()
		if parent != null:
			camera = parent.get_node_or_null("Camera2D") as Camera2D
	if config == null:
		config = load("res://resources/player/player_default.tres") as PlayerConfig
	if camera == null:
		push_error("CameraComponent: no Camera2D assigned or found.")
		return
	if config == null:
		push_error("CameraComponent: no PlayerConfig assigned.")
		return

	# This rig owns the smoothing. Leaving Camera2D's own position smoothing on
	# as well means two easing curves fight, which reads as soft laggy drift.
	camera.position_smoothing_enabled = false
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false

	# Resolve in the physics step, because that is when the rig is moved.
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.zoom = Vector2.ONE * config.camera_zoom
	call_deferred(&"_make_camera_current")


func _make_camera_current() -> void:
	if camera != null and camera.is_inside_tree():
		# Godot 4 replaced Camera2D.current with Camera2D.enabled; make_current()
		# alone is not enough because the scene sets no enabled flag.
		camera.enabled = true
		camera.make_current()


func set_floor_bounds(bounds: Rect2) -> void:
	_floor_bounds = bounds
	if camera == null:
		return
	# Match._setup_player() calls this before _wire_components() has necessarily
	# run, so resolve the config here too instead of dereferencing null below.
	if config == null:
		config = load("res://resources/player/player_default.tres") as PlayerConfig
	if config == null:
		push_warning("CameraComponent: set_floor_bounds called with no PlayerConfig; limits not applied.")
		return
	# Godot clamps the camera CENTRE to [limit + half_viewport, limit - half_viewport],
	# so the limits are expanded by half a viewport to reach the floor edges.
	# Camera zoom scales screen pixels per world unit; divide the viewport size by
	# zoom to get the actual world-space view.
	var half := visible_world_size() * 0.5
	var pad := bounds_overshoot
	camera.limit_left = int(bounds.position.x - half.x - pad)
	camera.limit_top = int(bounds.position.y - half.y - pad)
	camera.limit_right = int(bounds.position.x + bounds.size.x + half.x + pad)
	camera.limit_bottom = int(bounds.position.y + bounds.size.y + half.y + pad)


## Called once per physics frame from Player._physics_process().
func update(delta: float) -> void:
	if camera == null or config == null:
		return
	# `current` does not exist on Camera2D in Godot 4 — it is `enabled`.
	if not camera.enabled:
		camera.enabled = true
		camera.make_current()

	# The zoom is set before anything reads a viewport size: `_visible_size()`
	# depends on it, and the first frame otherwise framed the floor with the zoom
	# from the previous frame (which was unset on frame one).
	camera.zoom = Vector2.ONE * config.camera_zoom

	var body := camera.get_parent() as Node2D
	if body == null:
		return

	if _needs_initial_snap:
		# Match._setup_player() moves the body into place on a deferred call, which
		# may run after the first physics frame. Snapping on frame one would frame
		# the player at the origin and then drag the view across the whole floor, so
		# the snap waits until the body has actually left the scene origin.
		if body.global_position.is_zero_approx():
			return
		_anchor = body.global_position + Vector2(0.0, vertical_offset)
		camera.global_position = _anchor
		_needs_initial_snap = false

	_update_look_ahead(body, delta)
	_update_vertical(body, delta)
	_update_anchor(body)
	_apply_target(delta)
	_update_effects(delta)
	_debug_log()


# ------------------------------------------------------------------ horizontal

## Eases the horizontal lead toward the direction of committed movement.
func _update_look_ahead(body: Node2D, delta: float) -> void:
	var distance := look_ahead_distance
	if use_config_lead and config != null and config.camera_lead_pixels > 0.0:
		distance = config.camera_lead_pixels

	var goal := 0.0
	if body is CharacterBody2D:
		var speed_x := (body as CharacterBody2D).velocity.x
		if absf(speed_x) > look_ahead_commit_speed:
			goal = signf(speed_x) * distance
	_look_ahead = lerpf(_look_ahead, goal, _ease_weight(look_ahead_speed, delta))


# -------------------------------------------------------------------- vertical

## Handles the two vertical cases that must behave differently: a jump (frame
## holds still) and a fall (frame reveals the drop).
func _update_vertical(body: Node2D, delta: float) -> void:
	var goal := 0.0
	var on_floor := _body_on_floor(body)
	var speed_y := 0.0
	if body is CharacterBody2D:
		speed_y = (body as CharacterBody2D).velocity.y

	# Falling only. Rising is handled entirely by the vertical dead zone, so a
	# jump never pushes the frame and a climb is a dead-zone event.
	if not on_floor and speed_y > 0.0:
		goal = clampf(speed_y / maxf(fall_speed_reference, 1.0), 0.0, 1.0)
	_fall_percentage = lerpf(_fall_percentage, goal, _ease_weight(6.0, delta))

	# Once grounded, ease the remembered height back onto the player so a
	# staircase of jumps does not leave the anchor drifting below them.
	if on_floor:
		var weight := _ease_weight(ground_recenter_speed, delta)
		_anchor.y = lerpf(_anchor.y, body.global_position.y, weight)


# ---------------------------------------------------------------------- anchor

## Drags the anchor along only when the player reaches the edge of the dead zone.
## Inside the box nothing changes, which is what holds the frame still.
func _update_anchor(body: Node2D) -> void:
	var p := body.global_position
	var half := dead_zone * 0.5

	if p.x < _anchor.x - half.x:
		_anchor.x = p.x + half.x
	elif p.x > _anchor.x + half.x:
		_anchor.x = p.x - half.x

	if p.y < _anchor.y - half.y:
		_anchor.y = p.y + half.y
	elif p.y > _anchor.y + half.y:
		_anchor.y = p.y - half.y


func _apply_target(delta: float) -> void:
	var target := _anchor
	target.x += _look_ahead
	target.y += vertical_offset + _fall_percentage * fall_look_distance

	camera.global_position = camera.global_position.lerp(_clamp_target_to_floor(target), _ease_weight(follow_speed, delta))


func _clamp_target_to_floor(target: Vector2) -> Vector2:
	# Clamp the visible frame, not just its centre, or the camera reveals void
	# beyond the floor edges when the player walks against a wall.
	var half_view := visible_world_size() * 0.5
	var min_x := _floor_bounds.position.x - bounds_overshoot + half_view.x
	var max_x := _floor_bounds.end.x + bounds_overshoot - half_view.x
	var min_y := _floor_bounds.position.y - bounds_overshoot + half_view.y
	var max_y := _floor_bounds.end.y + bounds_overshoot - half_view.y
	if min_x > max_x:
		min_x = _floor_bounds.get_center().x
		max_x = min_x
	if min_y > max_y:
		min_y = _floor_bounds.get_center().y
		max_y = min_y
	target.x = clampf(target.x, min_x, max_x)
	target.y = clampf(target.y, min_y, max_y)
	return target


# --------------------------------------------------------------------- effects

func _update_effects(delta: float) -> void:
	if _shake_time < _shake_duration:
		_shake_time += delta
		var falloff := 1.0 - clampf(_shake_time / _shake_duration, 0.0, 1.0)
		var wave := sin(_shake_time * _shake_frequency * TAU)
		_shake_offset = _shake_dir * wave * _shake_strength * falloff
	else:
		_shake_offset = Vector2.ZERO

	_punch = _punch.lerp(Vector2.ZERO, _ease_weight(punch_recover, delta))

	# Effects live on Camera2D.offset so they never disturb the framing above.
	camera.offset = _shake_offset + _punch


## Directional shake. Directional rather than random because the axis carries the
## meaning: a landing shakes vertically, an attack shakes against the swing.
func shake(direction: Vector2, strength: float, duration: float, frequency: float = 20.0) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	_shake_dir = direction.normalized() if not direction.is_zero_approx() else Vector2.DOWN
	_shake_strength = strength
	_shake_duration = duration
	_shake_time = 0.0
	_shake_frequency = frequency


## A one-shot offset that eases back to zero on its own (landing impact).
func punch(offset: Vector2) -> void:
	_punch += offset


## Landing feedback: a downward punch plus a short vertical shake, both scaled by
## impact speed so a small hop does nothing and a real drop lands with weight.
##
## Returns without doing anything below `threshold`, because spending the impact
## budget on every hop leaves the real landings with nothing to say.
func on_landed(impact_speed: float, threshold: float = 320.0, ceiling: float = 1400.0) -> void:
	var t := clampf((impact_speed - threshold) / maxf(ceiling - threshold, 1.0), 0.0, 1.0)
	if t <= 0.0:
		return
	punch(Vector2(0.0, 10.0 * t))
	shake(Vector2.DOWN, 4.0 * t, 0.22, 20.0)


## Recoil feedback for firing a weapon. Shakes against the shot direction so it
## reads as the frame being pushed back by the muzzle.
func on_weapon_fired(aim_direction: Vector2, strength: float = 3.0) -> void:
	if aim_direction.is_zero_approx():
		return
	shake(-aim_direction.normalized(), strength, 0.12, 26.0)


# --------------------------------------------------------------------- helpers

## Frame-rate independent easing weight. A plain `speed * delta` lerp moves a
## different distance per second at 60 vs 144 fps; this does not.
func _ease_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-maxf(speed, 0.0) * delta)


func _body_on_floor(body: Node2D) -> bool:
	if body is CharacterBody2D:
		return (body as CharacterBody2D).is_on_floor()
	var movement := body.get_node_or_null("MovementComponent")
	if movement != null and movement.has_method(&"is_on_floor"):
		return bool(movement.call(&"is_on_floor"))
	return false


func _debug_log() -> void:
	if not OS.is_debug_build():
		return
	var frame := Engine.get_frames_drawn()
	if frame == _last_debug_frame or frame % 300 != 0:
		return
	_last_debug_frame = frame
	var view := visible_world_size()
	var top_left := camera.global_position - view * 0.5
	print("[DEBUG] CameraComponent: pos=%s zoom=%s view=%s" % [
		camera.global_position, camera.zoom, Rect2(top_left, view)
	])


## Re-centres the rig on the player immediately, with no easing.
##
## Used after floor travel and on respawn: without it the camera eases across the
## whole room from where the player used to be, which reads as the level sliding.
func snap_to_target() -> void:
	if camera == null:
		return
	var body := camera.get_parent() as Node2D
	if body == null:
		return
	_anchor = body.global_position + Vector2(0.0, vertical_offset)
	_look_ahead = 0.0
	_fall_percentage = 0.0
	_needs_initial_snap = false
	camera.global_position = _clamp_target_to_floor(_anchor)


## The world-space rectangle the camera currently shows, in gameplay world units.
## `get_viewport_rect()` is the wrong source in a headless run and during the
## first frames: it can report a 1x1 or stale size, which framed the floor with a
## 640x640 view. The project's configured viewport size is authoritative for a
## fixed-resolution 2D game; convert it to world units by dividing by zoom.
func visible_world_size() -> Vector2:
	if camera == null or config == null:
		return Vector2.ZERO
	var base := _configured_viewport_size()
	if base == Vector2.ZERO:
		base = camera.get_viewport_rect().size
	return base / config.camera_zoom


func _configured_viewport_size() -> Vector2:
	var w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	if w <= 0 or h <= 0:
		return Vector2.ZERO
	return Vector2(w, h)


func debug_line() -> String:
	return "cam %.0f,%.0f lead %.0f fall %.2f view %s" % [
		camera.global_position.x if camera != null else 0.0,
		camera.global_position.y if camera != null else 0.0,
		_look_ahead,
		_fall_percentage,
		visible_world_size(),
	]
