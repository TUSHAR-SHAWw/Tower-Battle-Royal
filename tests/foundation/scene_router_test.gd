extends TestCase

## SceneRouter must never crash a match on a typo.
##
## NOTE: this suite deliberately never calls goto() on a *valid* route — changing
## scenes would destroy the test runner itself. Successful transitions are covered
## by the manual checklist (docs/testing/manual_test_checklist.md).
## The "unknown route" test intentionally triggers one push_error() line in the
## engine log; that error is the expected behaviour, not a failure.


func test_boot_route_exists() -> void:
	assert_true(SceneRouter.has_route(SceneRouter.ROUTE_BOOT), "the boot route must exist")


func test_boot_route_points_at_a_real_scene() -> void:
	var path := SceneRouter.route_path(SceneRouter.ROUTE_BOOT)
	assert_true(ResourceLoader.exists(path), "boot scene is missing on disk: %s" % path)


func test_unknown_route_is_rejected_without_changing_scene() -> void:
	assert_eq(SceneRouter.goto(&"definitely_not_a_route"), ERR_DOES_NOT_EXIST)
	assert_eq(SceneRouter.current_route, &"", "a failed transition must not update current_route")


func test_planned_routes_are_declared_but_not_built() -> void:
	assert_true(SceneRouter.is_planned(SceneRouter.ROUTE_MATCH), "the match route is planned for M2")
	assert_false(SceneRouter.has_route(SceneRouter.ROUTE_MATCH), "the match scene must not exist yet in M0")


func test_reload_without_a_current_route_is_safe() -> void:
	assert_eq(SceneRouter.reload_current(), ERR_UNCONFIGURED)


func test_route_listing_is_not_empty() -> void:
	assert_greater(SceneRouter.list_routes().size(), 0.0, "at least the boot route must be registered")
