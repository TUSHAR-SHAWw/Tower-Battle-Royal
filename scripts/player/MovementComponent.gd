class_name MovementComponent
extends Node

## Integrates velocity for a side-view `CharacterBody2D`.
##
## Why a component: the player, bots and any future possessed actor share this
## maths, and state machine states must be able to ask "how fast am I going?"
## without each re-implementing acceleration, friction and gravity.
##
## Velocity deliberately lives on the body (`CharacterBody2D.velocity`) — one
## source of truth. This component only writes to it and calls `move_and_slide()`.

## The body to move. Assigned in the scene (NodePath ".." for a direct child),
## and re-resolved on demand by `_resolve_body()` when that failed.
@export var body: CharacterBody2D

## Optional config whose physics values override the exports below.
## Keeps gravity and jump height in ONE place (PlayerConfig) instead of splitting
## the same balance across a resource and a component's inspector defaults.
@export var config: PlayerConfig

## Downward acceleration in px/s^2.
@export var gravity: float = 2600.0

## Upward launch speed for a jump, in px/s.
@export var jump_velocity: float = -1000.0

## If true, keep `gravity` and `jump_velocity` in sync with `config`.
@export var use_config_physics: bool = true

## Max fall speed, in px/s. Stops the player accelerating forever.
@export var max_fall_speed: float = 1400.0

## How long after walking off a ledge the player can still jump. Makes jumps
## forgiving without giving infinite air jumps.
@export var coyote_time: float = 0.12

## How long a jump press is remembered before landing. Lets a slightly early
## press still register.
@export var jump_buffer_time: float = 0.12

## Multiplier applied to gravity while ascending and jump is held, for a floatier
## arc. 1.0 = no change.
@export var jump_hold_gravity_scale: float = 0.55

## Where the actor is looking. Aim-driven in this game (twin-stick), not
## movement-driven, so a player can strafe or back away while facing a target.
var facing: Vector2 = Vector2.RIGHT

## Multiplier for speed effects (Rage, hunger, ice slow, ...). 1.0 = unaffected.
var speed_multiplier: float = 1.0

## Vertical speed at touchdown that counts as a real impact rather than a step.
## Reported through `landed` so the camera can punch and shake.
@export var land_impact_threshold: float = 320.0

## Emitted on the frame the actor touches down, carrying the impact speed (px/s).
## Deliberately silent for a gentle step down: not every landing is an event.
signal landed(impact_speed: float)

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _jump_held: bool = false
## Downward speed recorded on the last airborne frame, used for the landing edge.
var _last_fall_speed: float = 0.0


func _ready() -> void:
	_resolve_body()
	_apply_config_physics()


## Resolves the body reference, and re-resolves it when a previous attempt failed.
##
## `_ready()` used to resolve this once and then give up. That made the component
## permanently inert whenever it was readied while its parent was still being set
## up — a scene instanced inside another node's `_ready()`, a player added during a
## busy frame — because `body` stayed null and every method below early-returned.
## Nothing errored, nothing moved, and the cause was invisible. Re-resolving here
## (and at the top of the write paths) means the component heals itself instead.
func _resolve_body() -> CharacterBody2D:
	if body != null and is_instance_valid(body):
		return body
	var parent := get_parent()
	if parent is CharacterBody2D:
		body = parent as CharacterBody2D
	elif parent != null:
		# Host may be a wrapper node (a Player controller with the body as a child).
		body = parent.get_parent() as CharacterBody2D
	return body


## Copies gravity and jump height from `config` when one is assigned.
func _apply_config_physics() -> void:
	if not use_config_physics:
		return
	if config == null and body != null:
		var value: Variant = body.get(&"config")
		if value is PlayerConfig:
			config = value as PlayerConfig
	if config == null:
		return
	gravity = config.gravity
	jump_velocity = config.jump_velocity


## Accelerates horizontally toward `direction * target_speed`.
##
## Vertical velocity is left alone: gravity owns the Y axis in a side view, so
## horizontal input must not fight it.
func accelerate_toward(direction: Vector2, target_speed: float, acceleration: float, delta: float) -> void:
	if _resolve_body() == null:
		return
	var desired_x := 0.0
	if not direction.is_zero_approx():
		# Normalise so diagonal input is not faster than straight input.
		desired_x = direction.normalized().x * maxf(target_speed * speed_multiplier, 0.0)
	body.velocity.x = move_toward(body.velocity.x, desired_x, maxf(acceleration, 0.0) * delta)


## Decelerates horizontally toward a standstill without inverting direction.
func brake(friction: float, delta: float) -> void:
	if _resolve_body() == null:
		return
	body.velocity.x = move_toward(body.velocity.x, 0.0, maxf(friction, 0.0) * delta)


## Applies gravity, resolves jump input, then moves the body.
##
## Call this once per physics frame instead of `commit()` in a side view so the
## gravity/jump bookkeeping stays in one place.
func apply_motion(delta: float) -> void:
	if _resolve_body() == null:
		return
	_update_ground_timers(delta)
	_apply_gravity(delta)
	_resolve_jump()
	commit()


## Decreases coyote time while airborne and (re)starts it on landing.
func _update_ground_timers(delta: float) -> void:
	var on_floor := body.is_on_floor()
	if on_floor:
		_coyote_timer = coyote_time
		# `_was_on_floor` was written every frame and never read, so landing was
		# never detected. This edge is what feeds the camera's land punch.
		if not _was_on_floor and _last_fall_speed >= land_impact_threshold:
			landed.emit(_last_fall_speed)
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		_last_fall_speed = maxf(body.velocity.y, 0.0)
	_was_on_floor = on_floor


func _apply_gravity(delta: float) -> void:
	var scale := jump_hold_gravity_scale if body.velocity.y < 0.0 and _jump_held else 1.0
	body.velocity.y = minf(body.velocity.y + gravity * scale * delta, max_fall_speed)


## Performs the jump if the buffered press is still valid and the player is
## grounded (or within the coyote window).
func _resolve_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return
	if _coyote_timer <= 0.0:
		return
	body.velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_jump_held = true


## Records a jump press; the actual launch may happen a few frames later.
func request_jump() -> void:
	_jump_buffer_timer = jump_buffer_time


## Called by the input layer each frame with the current jump-held state.
func set_jump_held(held: bool) -> void:
	_jump_held = held


## True while the player is standing on something.
func is_on_floor() -> bool:
	return _resolve_body() != null and body.is_on_floor()


## True when a jump is possible right now (grounded or within coyote time).
func can_jump() -> bool:
	return _coyote_timer > 0.0


## Stops instantly (death, respawn, teleports, arriving from floor travel).
func halt() -> void:
	if _resolve_body() == null:
		return
	body.velocity = Vector2.ZERO
	_jump_buffer_timer = 0.0
	_jump_held = false


## Applies the velocity through the physics engine. States call this once per
## physics frame after deciding on a velocity.
func commit() -> void:
	if _resolve_body() == null:
		return
	body.move_and_slide()


func velocity() -> Vector2:
	return body.velocity if body != null else Vector2.ZERO


func speed() -> float:
	return velocity().length()


func is_moving(threshold: float = 1.0) -> bool:
	return speed() > threshold


func set_facing(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	facing = direction.normalized()


func is_facing(dir: Vector2, tolerance_radians: float = 0.2) -> bool:
	return absf(MathUtils.angle_diff(facing.angle(), dir.angle())) <= tolerance_radians


## Temporarily multiplies speed_multiplier by `multiplier` for `duration` seconds.
func apply_speed_boost(multiplier: float, duration: float) -> void:
	speed_multiplier *= multiplier
	# Reset after duration
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	timer.timeout.connect(_on_speed_boost_end.bind(multiplier))
	add_child(timer)
	timer.start()


func _on_speed_boost_end(multiplier: float) -> void:
	speed_multiplier /= multiplier


func debug_line() -> String:
	return "%.0f px/s %s" % [speed(), _compass(facing)]


## Compass letter for the debug overlay (readable at a glance while tuning).
func _compass(direction: Vector2) -> String:
	if direction.is_zero_approx():
		return "-"
	var angle := direction.angle()
	if angle > -PI * 0.75 and angle <= -PI * 0.25:
		return "N"
	if angle > -PI * 0.25 and angle <= PI * 0.25:
		return "E"
	if angle > PI * 0.25 and angle <= PI * 0.75:
		return "S"
	return "W"
