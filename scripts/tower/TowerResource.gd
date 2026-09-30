class_name TowerResource
extends Resource

## Full tower configuration: all floors + central platform definition.
## Lives in `resources/tower/tower_definition.tres`.

## List of per-floor tower data. Floor 1 is top, floor N is bottom.
@export var floors: Array[TowerData] = []

## Index into `floors` where the central platform operates.
@export var central_platform_floor_index: int = 0

## Name of the central platform floor in `floors` (if it has one).
@export var central_platform_floor_id: int = 1

## How many floors total (convenience; mirrors `floors.size()`).
@export var total_floors: int = 0

## Starting floor for the match (randomized within [1, starting_floor_range]).
@export var starting_floor_range: int = 3

## How many top floors are "safe" (no deletion pressure) in the first minutes.
@export var soft_start_floors: int = 2

## Per-floor difficulty scaling multiplier (applied to enemy stats).
@export var difficulty_per_floor: float = 0.15

func _init() -> void:
	total_floors = floors.size()


func validate() -> Array[String]:
	var problems: Array[String] = []
	if floors.is_empty():
		problems.append("floors list is empty")
		return problems

	for i: int in floors.size():
		var fd: TowerData = floors[i]
		if fd == null:
			problems.append("floor at index %d is null" % i)
		elif fd.floor_id < 1:
			problems.append("floor %d has floor_id < 1" % i)
		elif fd.floor_data == null:
			problems.append("floor %d (%s) has no floor_data" % [i, fd.display_name])

	problems.append_array(_validate_platform())
	return problems


func _validate_platform() -> Array[String]:
	var problems: Array[String] = []
	if central_platform_floor_index < 0 or central_platform_floor_index >= floors.size():
		problems.append("central_platform_floor_index %d is out of range (0..%d)" % [
			central_platform_floor_index, floors.size() - 1
		])
	return problems


func get_floor(floor_id: int) -> TowerData:
	for fd in floors:
		if fd != null and fd.floor_id == floor_id:
			return fd
	return null


func get_floor_by_index(index: int) -> TowerData:
	if index < 0 or index >= floors.size():
		return null
	return floors[index] as TowerData


func get_central_platform_floor() -> TowerData:
	if central_platform_floor_id > 0:
		return get_floor(central_platform_floor_id)
	if central_platform_floor_index >= 0 and central_platform_floor_index < floors.size():
		return floors[central_platform_floor_index]
	return null


func get_difficulty_for_floor(floor_id: int) -> float:
	var idx := _find_index(floor_id)
	if idx < 0:
		return 1.0
	var progress := 1.0 - (float(idx) / float(floors.size()))
	return 1.0 + (1.0 - progress) * difficulty_per_floor * float(floors.size())


func _find_index(floor_id: int) -> int:
	for i: int in floors.size():
		var fd := floors[i] as TowerData
		if fd != null and fd.floor_id == floor_id:
			return i
	return -1


func get_sorted_floor_ids() -> Array[int]:
	var ids: Array[int] = []
	for fd in floors:
		if fd != null:
			ids.append(fd.floor_id)
	ids.sort()
	return ids
