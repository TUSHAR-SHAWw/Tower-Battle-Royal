extends TestCase

## Tests for the tower structure: TowerData, FloorData, and floor sequencing.
## Ensures all 10 floors plus the central platform are properly configured.

func test_tower_definition_exists() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	assert_not_null(tower, "tower_definition.tres must exist")

func test_tower_has_ten_floors() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	assert_eq(tower.floors.size(), 50, "tower should have 50 floors")
	assert_eq(tower.total_floors, 50, "total_floors should match the floor list")

func test_tower_floors_are_valid() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	for i: int in tower.floors.size():
		var fd: TowerData = tower.floors[i]
		assert_not_null(fd, "floor %d must not be null" % i)
		var problems := fd.validate()
		assert_true(problems.is_empty(), "floor %d (%s) validation: %s" % [i, fd.display_name, ", ".join(problems)])

func test_central_platform_exists() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var platform := tower.get_central_platform_floor()
	assert_not_null(platform, "central platform floor should exist")
	if platform != null:
		assert_true(platform.is_central_platform, "floor %d should be central platform" % platform.floor_id)

func test_central_platform_index_valid() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	assert_true(tower.central_platform_floor_index >= 0, "central_platform_floor_index must be >= 0")
	assert_true(tower.central_platform_floor_index < tower.floors.size(), "central_platform_floor_index must be < floors.size")

func test_floor_ids_are_sequential() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var ids: Array[int] = tower.get_sorted_floor_ids()
	for i: int in ids.size():
		assert_eq(ids[i], i + 1, "floor id at index %d should be %d" % [i, i + 1])

func test_floor_difficulty_scales() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var prev_mod := 0.0
	for i: int in tower.floors.size():
		var fd: TowerData = tower.floors[i]
		if fd == null:
			continue
		if i > 0:
			assert_greater(fd.difficulty_modifier, prev_mod, "floor %d difficulty should increase" % fd.floor_id)
		prev_mod = fd.difficulty_modifier

func test_floors_have_travel_targets() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	for fd: TowerData in tower.floors:
		if fd == null:
			continue
		if fd.is_central_platform:
			continue
		var target := int(fd.travel_portal_position.x)
		if fd.floor_id == tower.floors.size():
			continue  # bottom floor has no downward portal
		assert_true(target > 0, "floor %d should have a travel target" % fd.floor_id)

func test_central_platform_has_central_data() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var central_id: int = tower.central_platform_floor_id
	assert_true(central_id >= 1 and central_id <= tower.floors.size(),
		"central platform id %d must be inside the tower" % central_id)
	# is_central_platform lives on the TowerData entry, not on FloorData.
	var central: TowerData = tower.floors[central_id - 1]
	assert_not_null(central, "floor %d must exist" % central_id)
	if central != null:
		assert_true(central.is_central_platform,
			"floor %d should be flagged as the central platform" % central_id)
		assert_eq(central.floor_id, central_id, "central floor id must line up")

func test_floors_have_unique_ids() -> void:
	var tower := load("res://resources/tower/tower_definition.tres") as TowerResource
	var seen: Dictionary[int, bool] = {}
	for fd: TowerData in tower.floors:
		if fd == null:
			continue
		assert_false(seen.has(fd.floor_id), "floor_id %d is duplicated" % fd.floor_id)
		seen[fd.floor_id] = true
