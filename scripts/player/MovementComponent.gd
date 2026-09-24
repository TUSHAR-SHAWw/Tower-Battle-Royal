class_name MovementComponent
extends Node

## Integrates velocity for a top-down `CharacterBody2D`.
##
## Why a component: the player, bots and any future possessed actor share this
## maths, and state machine states must be able to ask "how fast am I going?"
## without each re-implementing acceleration and friction.
##
## Velocity deliberately lives on the body (`CharacterBody2D.velocity`) — one
## source of truth. This component only writes to it and calls `move_and_slide()`.

## The body to move. Assigned in the scene (NodePath ".." for a direct child).
@export var body: CharacterBody2D

## Where the actor is looking. Aim-driven in this game (twin-stick), not
## movement-driven, so a player can strafe or back away while facing a target.
var facing: Vector2 = Vector2.RIGHT

## Multiplier for speed effects (Rage, hunger, ice slow, ...). 1.0 = unaffected.
var speed_multiplier: float = 1.0


func _ready() -> void:
	if body == null:
		push_error("MovementComponent: no body assigned — this component will be inert.")


## Accelerates toward `direction * target_speed` (scaled by speed_multiplier).
func accelerate_toward(direction: Vector2, target_speed: float, acceleration: float, delta: float) -> void:
	if body == null:
		return
	var desired := Vector2.ZERO
	if not direction.is_zero_approx():
		# Normalise so diagonal input is not faster than straight input.
		desired = direction.normalized() * maxf(target_speed * speed_multiplier, 0.0)
	body.velocity = body.velocity.move_toward(desired, maxf(acceleration, 0.0) * delta)


## Decelerates toward a standstill without inverting direction.
func brake(friction: float, delta: float) -> void:
	if body == null:
		return
	body.velocity = body.velocity.move_toward(Vector2.ZERO, maxf(friction, 0.0) * delta)


## Stops instantly (death, respawn, teleports, arriving from floor travel).
func halt() -> void:
	if body == null:
		return
	body.velocity = Vector2.ZERO


## Applies the velocity through the physics engine. States call this once per
## physics frame after deciding on a velocity.
func commit() -> void:
	if body == null:
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
