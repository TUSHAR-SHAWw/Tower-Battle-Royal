class_name MapResource
extends Resource

## World map configuration. Lives in `resources/map/*.tres`.

@export var map_name: String = "Tower"
@export var total_floors: int = 20
@export var central_platform_floor: int = 0  # 0 = no central platform, or floor index

@export_group("Floor Layout (index = floor_id - 1)")
@export var floor_positions: Array[Vector2i] = []  # grid positions in tower
@export var floor_connections: Dictionary = {}   # floor_id -> [connected_floor_ids]

@export_group("Visual")
@export var tower_width: int = 5      # grid width
@export var tower_height: int = 20     # grid height
@export var cell_size: float = 32.0    # pixels per cell in minimap
@export var unexplored_color: Color = Color(0.1, 0.1, 0.15, 1.0)
@export var explored_color: Color = Color(0.2, 0.3, 0.5, 1.0)
@export var current_floor_color: Color = Color(0.2, 0.8, 1.0, 1.0)
@export var completed_floor_color: Color = Color(0.2, 1.0, 0.4, 1.0)
@export var central_platform_color: Color = Color(1.0, 0.9, 0.3, 1.0)
@export var connection_color: Color = Color(0.4, 0.6, 0.8, 0.8)

func validate() -> Array[String]:
	var problems: Array[String] = []
	if total_floors < 1:
		problems.append("total_floors must be >= 1")
	if floor_positions.size() != total_floors:
		problems.append("floor_positions must have exactly total_floors entries")
	return problems


func get_floor_position(floor_id: int) -> Vector2i:
	if floor_id >= 1 and floor_id <= floor_positions.size():
		return floor_positions[floor_id - 1]
	return Vector2i(0, 0)


func get_connected_floors(floor_id: int) -> Array[int]:
	if floor_connections.has(floor_id):
		return floor_connections[floor_id]
	return []


func is_floor_connected(from_floor: int, to_floor: int) -> bool:
	var connections := get_connected_floors(from_floor)
	return connections.has(to_floor)