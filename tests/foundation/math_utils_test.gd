extends TestCase

## Movement, aiming, spread, loot rolls and melee arcs all lean on MathUtils.
## Being pure functions they need no scene — only a seeded RNG so runs repeat.

var _rng := RandomNumberGenerator.new()


func before_suite() -> void:
	_rng.seed = 20260923  # fixed seed: a failure must be reproducible


func test_angle_diff_takes_the_short_way_around() -> void:
	assert_almost_eq(MathUtils.angle_diff(0.0, deg_to_rad(10.0)), deg_to_rad(10.0))
	assert_almost_eq(MathUtils.angle_diff(0.0, deg_to_rad(350.0)), deg_to_rad(-10.0), "wrapping must be signed")
	assert_almost_eq(MathUtils.angle_diff(deg_to_rad(170.0), deg_to_rad(-170.0)), deg_to_rad(20.0))
	assert_almost_eq(MathUtils.angle_diff(PI * 0.5, PI * 0.5), 0.0)


func test_wrap_angle_stays_in_range() -> void:
	assert_almost_eq(MathUtils.wrap_angle(0.0), 0.0)
	assert_almost_eq(MathUtils.wrap_angle(TAU), 0.0)
	assert_almost_eq(MathUtils.wrap_angle(-TAU), 0.0)
	assert_almost_eq(MathUtils.wrap_angle(PI * 3.0), -PI, "3*PI wraps to -PI in a [-PI, PI) range")
	for _i: int in 50:
		var wrapped := MathUtils.wrap_angle(_rng.randf_range(-100.0, 100.0))
		assert_in_range(wrapped, -PI, PI)


func test_vector_from_angle_and_angle_to_are_inverse() -> void:
	var direction := MathUtils.vector_from_angle(deg_to_rad(35.0), 10.0)
	assert_almost_eq(direction.length(), 10.0, "length must be respected")
	assert_almost_eq(MathUtils.angle_to(Vector2.ZERO, direction), deg_to_rad(35.0), "", 0.001)


func test_approach_never_overshoots() -> void:
	assert_eq(MathUtils.approach(Vector2.ZERO, Vector2(10.0, 0.0), 2.0), Vector2(2.0, 0.0))
	assert_eq(MathUtils.approach(Vector2.ZERO, Vector2(1.0, 0.0), 5.0), Vector2(1.0, 0.0), "close targets snap")
	assert_eq(MathUtils.approach(Vector2(3.0, 3.0), Vector2(3.0, 3.0), 1.0), Vector2(3.0, 3.0))


func test_approach_float_handles_both_directions() -> void:
	assert_almost_eq(MathUtils.approach_float(0.0, 10.0, 3.0), 3.0)
	assert_almost_eq(MathUtils.approach_float(0.0, -10.0, 3.0), -3.0)
	assert_almost_eq(MathUtils.approach_float(0.5, 0.0, 3.0), 0.0)


func test_clamp_length() -> void:
	assert_eq(MathUtils.clamp_length(Vector2(10.0, 0.0), 4.0), Vector2(4.0, 0.0))
	assert_eq(MathUtils.clamp_length(Vector2(1.0, 0.0), 4.0), Vector2(1.0, 0.0))
	assert_eq(MathUtils.clamp_length(Vector2(10.0, 0.0), 0.0), Vector2.ZERO, "zero max length means no movement")


func test_random_in_circle_stays_inside() -> void:
	for _i: int in 200:
		var point := MathUtils.random_in_circle(25.0, _rng)
		assert_less(point.length(), 25.0001, "a spawn point escaped its radius")
	assert_eq(MathUtils.random_in_circle(0.0, _rng), Vector2.ZERO)
	assert_eq(MathUtils.random_in_circle(-5.0, _rng), Vector2.ZERO, "negative radius is meaningless, not a crash")


func test_random_unit_is_normalised() -> void:
	for _i: int in 50:
		assert_almost_eq(MathUtils.random_unit(_rng).length(), 1.0, "", 0.001)


func test_weighted_pick_respects_weights() -> void:
	var weights := PackedFloat32Array([1.0, 0.0, 3.0])
	for _i: int in 200:
		var index := MathUtils.weighted_pick(weights, _rng)
		assert_true(index == 0 or index == 2, "zero-weight entries must never be picked (got %d)" % index)
	assert_eq(MathUtils.weighted_pick(PackedFloat32Array(), _rng), -1, "empty tables return -1")
	assert_eq(MathUtils.weighted_pick(PackedFloat32Array([0.0, 0.0]), _rng), -1, "all-zero tables return -1")
	assert_eq(MathUtils.weighted_pick(PackedFloat32Array([-5.0, 2.0]), _rng), 1, "negative weights count as zero")


func test_weighted_pick_is_deterministic_for_a_seed() -> void:
	var weights := PackedFloat32Array([1.0, 1.0, 1.0])
	var first := RandomNumberGenerator.new()
	first.seed = 1234
	var second := RandomNumberGenerator.new()
	second.seed = 1234
	var first_rolls := PackedInt32Array()
	var second_rolls := PackedInt32Array()
	for _i: int in 20:
		first_rolls.append(MathUtils.weighted_pick(weights, first))
		second_rolls.append(MathUtils.weighted_pick(weights, second))
	assert_eq(first_rolls, second_rolls, "server-authoritative play depends on seeded determinism")


func test_spread_direction_stays_inside_the_cone() -> void:
	var base := Vector2.RIGHT
	var spread := MathUtils.spread_direction(base, 5.0, _rng)
	assert_less(absf(MathUtils.angle_diff(base.angle(), spread.angle())), deg_to_rad(5.001))
	assert_almost_eq(spread.length(), 1.0, "", 0.001)
	assert_eq(MathUtils.spread_direction(base, 0.0, _rng), base, "zero spread must not jitter")


func test_is_in_cone() -> void:
	var origin := Vector2.ZERO
	var facing := Vector2.RIGHT
	assert_true(MathUtils.is_in_cone(origin, facing, Vector2(50.0, 0.0), 100.0, 45.0), "straight ahead")
	assert_true(MathUtils.is_in_cone(origin, facing, Vector2(50.0, 40.0), 100.0, 45.0), "inside the arc")
	assert_false(MathUtils.is_in_cone(origin, facing, Vector2(50.0, -90.0), 100.0, 45.0), "outside the arc")
	assert_false(MathUtils.is_in_cone(origin, facing, Vector2(500.0, 0.0), 100.0, 45.0), "out of reach")
	assert_true(MathUtils.is_in_cone(origin, facing, origin, 100.0, 45.0), "a target on top of you is hit")
	assert_false(MathUtils.is_in_cone(origin, Vector2.ZERO, Vector2(5.0, 0.0), 1.0, 45.0), "reach is checked before facing")
	assert_true(MathUtils.is_in_cone(origin, Vector2.ZERO, Vector2(5.0, 0.0), 10.0, 45.0), "no facing means no direction filter")
