class_name InputIntent
extends RefCounted

## What the player *wants* to do this frame, independent of the device.
##
## Why this exists (master prompt §40/§41): a keyboard player, a bot, a replay and
## — later — a remote networked player must all be able to drive the same player
## components. Components therefore never call `Input` directly; they read the
## intent produced by whatever InputSource is attached.
##
## Lifecycle: one instance per source, mutated and re-`reset()` every frame
## (poll -> read -> discard). Reusing the object keeps the hot path allocation
## free, so consumers must not store it beyond the frame they receive it.

# ------------------------------------------------------------------- movement
var move_dir: Vector2 = Vector2.ZERO          ## Normalised world-space direction.
var sprint_held: bool = false

# ----------------------------------------------------------------------- aiming
var aim_dir: Vector2 = Vector2.RIGHT          ## Normalised world-space aim.
## Mouse aiming gives an exact world point; stick aiming only gives a direction.
var aim_position: Vector2 = Vector2.ZERO
var has_aim_position: bool = false

# ----------------------------------------------------------------------- actions
var fire_held: bool = false
var fire_pressed: bool = false
var reload_pressed: bool = false
var melee_pressed: bool = false
var interact_pressed: bool = false
var use_pressed: bool = false
var map_pressed: bool = false
## 0-based hotbar slot when a slot key was pressed this frame, -1 otherwise.
var requested_slot: int = -1


func reset() -> void:
	move_dir = Vector2.ZERO
	sprint_held = false
	aim_dir = Vector2.RIGHT
	aim_position = Vector2.ZERO
	has_aim_position = false
	fire_held = false
	fire_pressed = false
	reload_pressed = false
	melee_pressed = false
	interact_pressed = false
	use_pressed = false
	map_pressed = false
	requested_slot = -1


func copy_from(other: InputIntent) -> void:
	move_dir = other.move_dir
	sprint_held = other.sprint_held
	aim_dir = other.aim_dir
	aim_position = other.aim_position
	has_aim_position = other.has_aim_position
	fire_held = other.fire_held
	fire_pressed = other.fire_pressed
	reload_pressed = other.reload_pressed
	melee_pressed = other.melee_pressed
	interact_pressed = other.interact_pressed
	use_pressed = other.use_pressed
	map_pressed = other.map_pressed
	requested_slot = other.requested_slot


## True when the player is asking to move at all.
func is_moving() -> bool:
	return move_dir.length_squared() > 0.0001


func _to_string() -> String:
	return "InputIntent(move=%s aim=%s fire=%s reload=%s melee=%s slot=%d)" % [
		move_dir, aim_dir, fire_held, fire_pressed, melee_pressed, requested_slot,
	]
