class_name MathUtils
extends RefCounted

## Small pure maths helpers shared by movement, aiming, spawning and looting.
##
## Pure functions (no nodes, no state) so they can be unit tested without a scene
## — see tests/foundation/math_utils_test.gd. Randomness always takes an explicit
## RandomNumberGenerator so a seeded test run is reproducible, which the future
## server-authoritative multiplayer mode also depends on.

## Shortest signed angle from `from_angle` to `to_angle`, in (-PI, PI].
static func angle_diff(from_angle: float, to_angle: float) -> float:
	return fposmod(to_angle - from_angle + PI, TAU) - PI


## Wraps an angle into [-PI, PI) (so 3*PI becomes -PI and TAU becomes 0).
static func wrap_angle(angle: float) -> float:
	return fposmod(angle + PI, TAU) - PI


static func vector_from_angle(angle: float, length: float = 1.0) -> Vector2:
	return Vector2(cos(angle), sin(angle)) * length


static func angle_to(from: Vector2, to: Vector2) -> float:
	return (to - from).angle()


## Moves `current` toward `target` by at most `max_delta` (never overshoots).
static func approach(current: Vector2, target: Vector2, max_delta: float) -> Vector2:
	var offset := target - current
	var distance := offset.length()
	if distance <= max_delta or distance == 0.0:
		return target
	return current + offset / distance * max_delta


## Same as approach() for floats.
static func approach_float(current: float, target: float, max_delta: float) -> float:
	if absf(target - current) <= max_delta:
		return target
	return current + signf(target - current) * max_delta


static func clamp_length(vector: Vector2, max_length: float) -> Vector2:
	if max_length <= 0.0:
		return Vector2.ZERO
	if vector.length() <= max_length:
		return vector
	return vector.normalized() * max_length


## Uniform random point inside a circle (sqrt keeps the distribution even instead
## of clustering at the centre).
static func random_in_circle(radius: float, rng: RandomNumberGenerator) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var angle := rng.randf_range(0.0, TAU)
	var distance := radius * sqrt(rng.randf())
	return vector_from_angle(angle, distance)


## Uniform random unit vector.
static func random_unit(rng: RandomNumberGenerator) -> Vector2:
	return vector_from_angle(rng.randf_range(0.0, TAU))


## Index picked from `weights` proportionally (loot tables, spread patterns).
## Returns -1 when nothing is pickable. Negative weights count as zero.
static func weighted_pick(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight: float in weights:
		if weight > 0.0:
			total += weight
	if total <= 0.0:
		return -1
	var roll := rng.randf_range(0.0, total)
	var accumulated := 0.0
	for index: int in weights.size():
		var weight := weights[index]
		if weight <= 0.0:
			continue
		accumulated += weight
		if roll < accumulated:
			return index
	return weights.size() - 1


## Random deviation inside a cone around `direction` (weapon spread).
static func spread_direction(direction: Vector2, max_degrees: float, rng: RandomNumberGenerator) -> Vector2:
	if max_degrees <= 0.0:
		return direction.normalized()
	var offset := deg_to_rad(rng.randf_range(-max_degrees, max_degrees))
	return vector_from_angle(direction.angle() + offset)


## True when `target` is inside a cone (melee arcs, vision checks).
## `half_angle_degrees` is measured from `facing`.
static func is_in_cone(origin: Vector2, facing: Vector2, target: Vector2, reach: float, half_angle_degrees: float) -> bool:
	var offset := target - origin
	var distance := offset.length()
	if distance > reach:
		return false
	if distance < 0.0001:
		return true
	if facing.is_zero_approx():
		return true
	return absf(rad_to_deg(angle_diff(facing.angle(), offset.angle()))) <= half_angle_degrees
