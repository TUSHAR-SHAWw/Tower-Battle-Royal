class_name PlayerConfig
extends Resource

## Every tunable number for a player. Lives in `resources/player/player_default.tres`
## so balance can change without touching code (master prompt §47), and so one
## resource can describe a bot, a test dummy or a future "heavy" variant.
##
## Values are PROTOTYPE DEFAULTS — not final balance. Pixel units, see
## docs/ARCHITECTURE.md §2.

@export_group("Movement")
## Radius of the collision circle. Art is deliberately independent of this.
@export var radius: float = 14.0
@export var walk_speed: float = 220.0
@export var sprint_speed: float = 320.0
@export var acceleration: float = 1800.0
## Speed lost per second when no input is held (stopping is snappier than starting).
@export var friction: float = 2200.0

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Camera")
@export var camera_zoom: float = 1.0
## Pixels the camera leans toward the aim direction (0 disables the lean).
@export var camera_lead_pixels: float = 48.0
@export var camera_smoothing_speed: float = 8.0

@export_group("Visual")
@export var body_color: Color = Color("#5ec2f5")
@export var outline_color: Color = Color("#10314a")
@export var visor_color: Color = Color("#eaf6ff")
@export var outline_width: float = 2.5


## Returns the list of problems with this configuration (empty means valid).
## Used by tests and by the debug tooling instead of trusting the editor.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if radius <= 0.0:
		problems.append("radius must be > 0 (got %.2f)" % radius)
	if walk_speed <= 0.0:
		problems.append("walk_speed must be > 0 (got %.2f)" % walk_speed)
	if sprint_speed < walk_speed:
		problems.append("sprint_speed (%.2f) must be >= walk_speed (%.2f)" % [sprint_speed, walk_speed])
	if acceleration <= 0.0:
		problems.append("acceleration must be > 0 (got %.2f)" % acceleration)
	if friction <= 0.0:
		problems.append("friction must be > 0 (got %.2f)" % friction)
	if max_health <= 0.0:
		problems.append("max_health must be > 0 (got %.2f)" % max_health)
	if camera_zoom <= 0.0:
		problems.append("camera_zoom must be > 0 (got %.2f)" % camera_zoom)
	if camera_lead_pixels < 0.0:
		problems.append("camera_lead_pixels must be >= 0 (got %.2f)" % camera_lead_pixels)
	return problems
