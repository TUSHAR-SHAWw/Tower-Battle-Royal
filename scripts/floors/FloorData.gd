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
## World-space bounds of the floor.
##
## Every floor in the tower is the SAME size so the camera never has to re-frame
## and floor travel is a clean teleport.
##
## The height is sized around the player, not the other way round: the character
## is drawn at PLAYER_HEIGHT_RATIO (1/5) of it, so a 1080-tall floor makes the
## player 216 px — a person standing in a room, which is what the reference art
## looks like. At 216 px the player is 0.2% of a 3840-wide floor, which reads as a
## dot; the floor is therefore widened to 6400 so the room has the same 6:1
## character-to-room proportions as the reference (a person is roughly 1/6 of the
## room they stand in).
##
## 6400 x 1080 at 1.5x zoom shows 853x480, so the room scrolls horizontally across
## roughly 7.5 screens — the Silksong framing — while four players get ~1600 px of
## personal space each, enough to spread, flank, and miss shots.
@export var bounds: Rect2 = Rect2(-3200, -1080, 6400, 1080)

## Width of the central shaft cut through the slab, in pixels.
##
## The shaft is the only vertical opening in a floor. The descending platform
## rides down it, loot spawns on its lip, and falling in drops you a floor.
## Sized to 2.5x the platform diameter so the platform never clips the slab.
@export var shaft_width: float = 640.0
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
@export_group("Tower")
@export var is_central_platform: bool = false


## Canonical floor size shared by every floor in the tower. Keep FloorData.bounds
## in sync with this; a floor that differs will not frame correctly.
const DEFAULT_BOUNDS := Rect2(-3200, -1080, 6400, 1080)
const DEFAULT_SHAFT_WIDTH := 640.0

## How tall the player is drawn, as a fraction of the floor height. Lives here so
## the floor and the character are sized from one number.
const PLAYER_HEIGHT_RATIO := 0.2


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
	if bounds != DEFAULT_BOUNDS:
		problems.append("bounds must be %s so the camera framing stays uniform (got %s)" % [DEFAULT_BOUNDS, bounds])
	if shaft_width <= 0.0:
		problems.append("shaft_width must be > 0 (got %.1f)" % shaft_width)
	if shaft_width >= bounds.size.x - 400.0:
		problems.append("shaft_width (%.1f) leaves no walkable floor on a %.1f-wide floor" % [shaft_width, bounds.size.x])
	if height < 0:
		problems.append("height must be >= 0 (got %.1f)" % height)
	if danger_level < 1 or danger_level > 5:
		problems.append("danger_level must be 1..5 (got %d)" % danger_level)
	return problems