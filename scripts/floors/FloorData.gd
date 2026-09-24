class_name FloorData
extends Resource

## Configuration for a single tower floor.
##
## Floors are data-driven — the same FloorController scene is used for all
## floors, configured by this resource. This keeps memory low (only the current
## floor scene is loaded) and makes the tower easily extensible.
##
## Values are PROTOTYPE DEFAULTS — not final balance. Pixel units.

@export_group("Identity")
@export var floor_id: int = 1
@export var display_name: String = "Floor 1"

@export_group("Geometry")
## World-space bounds of the floor (centre at 0,0 by default).
@export var bounds: Rect2 = Rect2(-1280, -720, 2560, 1440)
## Vertical position in the tower (pixels from ground). Used for ordering.
@export var height: float = 0.0

@export_group("Theme / Atmosphere")
@export var theme_name: String = "concrete"
@export var ambient_color: Color = Color(0.15, 0.15, 0.18, 1.0)
@export var danger_level: int = 1  # 1 = low, 5 = extreme

@export_group("Loot")
@export var loot_table_path: String = ""
@export var loot_spawn_points: Array[Vector2] = []

@export_group("State")
@export var initial_state: int = 0  # 0=ACTIVE, 1=WARNING, 2=COLLAPSING, 3=DELETED


## Floor state enum (mirrored in FloorController).
enum FloorState {
	ACTIVE = 0,
	WARNING = 1,
	COLLAPSING = 2,
	DELETED = 3,
}


## Returns the list of problems with this configuration (empty means valid).
func validate() -> Array[String]:
	var problems: Array[String] = []
	if floor_id <= 0:
		problems.append("floor_id must be > 0 (got %d)" % floor_id)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		problems.append("bounds size must be positive (got %s)" % bounds.size)
	if height < 0:
		problems.append("height must be >= 0 (got %.1f)" % height)
	if danger_level < 1 or danger_level > 5:
		problems.append("danger_level must be 1..5 (got %d)" % danger_level)
	return problems