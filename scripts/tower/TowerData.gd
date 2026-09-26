class_name TowerData
extends Resource

## Data for a single tower floor. Lives in `resources/tower/*.tres`.

@export var floor_id: int = 1
@export var display_name: String = "Floor %d"
@export var floor_scene: PackedScene
@export var floor_data: FloorData
@export var travel_portal_position: Vector2 = Vector2.ZERO
@export var is_central_platform: bool = false
@export var difficulty_modifier: float = 1.0

func validate() -> Array[String]:
	var problems: Array[String] = []
	if floor_id < 1:
		problems.append("floor_id must be >= 1 (got %d)" % floor_id)
	if floor_scene == null:
		problems.append("floor_scene not assigned")
	if floor_data == null:
		problems.append("floor_data not assigned")
	return problems