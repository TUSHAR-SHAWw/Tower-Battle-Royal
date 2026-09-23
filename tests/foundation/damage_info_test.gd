extends TestCase

## DamageInfo is the one object every combat system passes around, so its
## defaults and fluent builders are pinned here (master prompt §14).

var _shooter: Node
var _projectile: Node


func before_each() -> void:
	_shooter = Node.new()
	_shooter.name = "Shooter"
	add_child(_shooter)
	_projectile = Node.new()
	_projectile.name = "Projectile"
	add_child(_projectile)


func after_each() -> void:
	_shooter.queue_free()
	_projectile.queue_free()


func test_create_sets_amount_type_and_actors() -> void:
	var info := DamageInfo.create(12.5, DamageTypes.BULLET, _shooter, _projectile)
	assert_almost_eq(info.amount, 12.5)
	assert_eq(info.type, DamageTypes.BULLET)
	assert_eq(info.instigator, _shooter, "kill credit belongs to the shooter")
	assert_eq(info.source, _projectile, "hit VFX/audio wants the projectile")


func test_defaults_are_physical_bullet_damage() -> void:
	var info := DamageInfo.create(5.0)
	assert_eq(info.type, DamageTypes.BULLET)
	assert_eq(info.element, &"", "no element means physical")
	assert_false(info.is_critical)
	assert_eq(info.hit_position, Vector2.ZERO)
	assert_false(info.has_knockback())


func test_negative_amount_is_clamped() -> void:
	assert_almost_eq(DamageInfo.create(-30.0).amount, 0.0, "negative damage must never heal a target")


func test_knockback_uses_a_normalised_direction() -> void:
	var info := DamageInfo.create(1.0).with_knockback(Vector2(300.0, 0.0), 200.0)
	assert_almost_eq(info.knockback.length(), 200.0, "force is the impulse magnitude")
	assert_almost_eq(info.knockback.x, 200.0)


func test_zero_force_or_zero_direction_means_no_knockback() -> void:
	assert_false(DamageInfo.create(1.0).with_knockback(Vector2.RIGHT, 0.0).has_knockback())
	assert_false(DamageInfo.create(1.0).with_knockback(Vector2.ZERO, 500.0).has_knockback())


func test_fluent_builders_chain_on_one_object() -> void:
	var info := DamageInfo.create(20.0, DamageTypes.MELEE, _shooter)
	var chained := info.with_element(&"fire").with_critical(true).with_hit_position(Vector2(4.0, 9.0)).with_knockback(Vector2.LEFT, 120.0)
	assert_eq(chained, info, "builders must mutate and return the same instance")
	assert_eq(info.element, &"fire")
	assert_true(info.is_critical)
	assert_eq(info.hit_position, Vector2(4.0, 9.0))
	assert_true(info.has_knockback())


func test_with_amount_keeps_the_same_object() -> void:
	var info := DamageInfo.create(10.0)
	assert_eq(info.with_amount(4.0).with_amount(-1.0).amount, 0.0, "with_amount clamps too")


func test_is_from_matches_instigator_or_source() -> void:
	var info := DamageInfo.create(1.0, DamageTypes.BULLET, _shooter, _projectile)
	assert_true(info.is_from(_shooter))
	assert_true(info.is_from(_projectile))
	assert_false(info.is_from(self), "unrelated nodes must not be credited")
	assert_false(info.is_from(null), "a null check must not crash (self-damage from explosions)")


func test_damage_types_are_validated() -> void:
	for damage_type: StringName in DamageTypes.all():
		assert_true(DamageTypes.is_valid(damage_type), "DamageTypes.all() must only contain valid ids")
	assert_false(DamageTypes.is_valid(&"laser_beam_of_doom"), "unknown ids must be rejected, not accepted silently")
	assert_false(DamageTypes.is_valid(&""), "an empty damage type is a bug at the call site")


func test_only_unavoidable_damage_bypasses_defense() -> void:
	assert_true(DamageTypes.bypasses_defense(DamageTypes.UNAVOIDABLE))
	assert_true(DamageTypes.bypasses_defense(DamageTypes.STARVATION), "hunger damage cannot be blocked by melee")
	assert_false(DamageTypes.bypasses_defense(DamageTypes.BULLET), "bullets are reduced by melee defense (M4)")


func test_to_string_survives_missing_actors() -> void:
	var info := DamageInfo.create(3.0)
	assert_true(str(info).contains("amount=3"), "the debug overlay and logs print this")
