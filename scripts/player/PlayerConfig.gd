class_name PlayerConfig
extends Resource

## Every tunable number for a player. Lives in `resources/player/player_default.tres`
## so balance can change without touching code (master prompt §47), and so one
## resource can describe a bot, a test dummy or a future "heavy" variant.
##
## Values are PROTOTYPE DEFAULTS — not final balance. Pixel units, see
## docs/ARCHITECTURE.md §2.

@export_group("Movement")
## Radius of the collision circle, in pixels.
##
## Matched to the drawn character: the sprite is 1/5 of the floor height (216 px on
## a 1080 floor), so a radius of ~70 gives a 140 px body — slightly narrower than
## the art, which is what you want in a platformer, since a collision circle that
## matches the sprite exactly makes every ledge feel like it is grabbing you.
@export var radius: float = 70.0

## Movement speeds scale with the character, not the floor: these were tuned for a
## 28 px body, and a 140 px body crossing a 6400 px room at 220 px/s would take
## half a minute to walk across. Scaled ~5x with the body.
@export var walk_speed: float = 620.0
@export var sprint_speed: float = 900.0
@export var acceleration: float = 4200.0
## Speed lost per second when no input is held (stopping is snappier than starting).
## MUST stay below `acceleration`: IdleState brakes and accelerates on the same
## frame, so friction > acceleration means a standing player can never reach walk
## speed. Kept at the original 2200/1800 ratio.
@export var friction: float = 3400.0

@export_group("Physics")
## Downward acceleration in px/s^2. MovementComponent reads this at startup.
@export var gravity: float = 2600.0
## Upward launch speed for a jump, in px/s.
##
## Peaks at v²/2g = 880²/(2×2600) ≈ 149 px. That MUST stay under the camera's
## vertical dead zone (190 px) or a routine jump drags the frame away from the
## ground line — which is exactly what a 1000 px/s launch did at 192 px. It is
## also about two-thirds of the 216 px body height, which is what makes a jump
## read as clearing a ledge rather than as flying.
@export var jump_velocity: float = -880.0

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Camera")
## Zoom for the framing rig. 0.75 shows 1707x960 of a 6400-wide floor — twice the
## area of the 1.5 default — so the room scrolls horizontally while the ~216 px
## character still reads clearly on screen.
@export var camera_zoom: float = 0.75
## How far the frame leads in the direction of committed movement (0 disables it).
## Read by CameraComponent when use_config_lead is on.
@export var camera_lead_pixels: float = 150.0
## How fast the rig catches up. Higher is snappier.
@export var camera_smoothing_speed: float = 6.0

@export_group("Visual")
@export var body_color: Color = Color("#5ec2f5")
@export var accent_color: Color = Color("#eaf6ff")
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
	if friction > acceleration:
		problems.append("friction (%.2f) must not exceed acceleration (%.2f): IdleState brakes and accelerates on the same frame, so the player could never reach walk speed" % [friction, acceleration])
	if camera_zoom <= 0.0:
		problems.append("camera_zoom must be > 0 (got %.2f)" % camera_zoom)
	if camera_lead_pixels < 0.0:
		problems.append("camera_lead_pixels must be >= 0 (got %.2f)" % camera_lead_pixels)
	return problems
