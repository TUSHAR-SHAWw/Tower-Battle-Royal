class_name VisualComponent
extends Node2D

## Renders the player: an AnimatedSprite2D when sprite frames are available,
## otherwise the flat-vector placeholder circle.
##
## Purely presentational — no gameplay logic here. The body colour, outline and
## visor come from PlayerConfig so skins can replace this without touching code.

@export var config: PlayerConfig
@export var skin: SkinResource = null

## The floor is drawn by a sibling Node2D that appears earlier in the Match scene
## tree, so without this the floor's opaque background paints over the player.
## A positive z_index keeps the player above the floor regardless of tree order.
@export var z_order: int = 10

## Sprite scale is applied here, so the drawn size is this ratio of the floor
## height once set_floor_height() has run.

## Falls back to the drawn circle when true. Useful while the sprite art is
## still being chosen.
@export var use_sprite: bool = true

## How tall the character is drawn, in world pixels.
##
## Expressed as a fraction of the floor height rather than a fixed size so the
## player keeps the same visual weight if floors are ever resized: a person should
## read as a person standing in a room, not as a dot on a wall.
## PROTOTYPE DEFAULT — the developer asked for 1/5 of the floor height.
@export var drawn_height_ratio: float = 0.2

@onready var _sprite: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D

var _last_facing_sign: float = 1.0
var _drawn_height: float = 0.0


## Rebuilds the sprite frames and sets the node scale so the character is
## `floor_height * drawn_height_ratio` pixels tall. Called by Player once the
## floor size is known.
##
## The scale lives on the AnimatedSprite2D, NOT on the AtlasTexture: AtlasTexture
## has no `scale` property, and assigning one silently produced a null frame (an
## invisible player) instead of an error you could see.
func set_floor_height(floor_height: float) -> void:
	_drawn_height = maxf(floor_height * drawn_height_ratio, 8.0)
	if _sprite == null:
		return
	_sprite.sprite_frames = PlayerSpriteFrames.build()
	var factor := _drawn_height / float(PlayerSpriteFrames.TILE)
	_sprite.scale = Vector2(factor, factor)
	# The sheet's characters stand with their feet at the bottom of the cell, so
	# the sprite is lifted by a fraction of its own height to line those feet up
	# with the bottom of the collision circle. The offset is in the sprite's own
	# (unscaled) space, so it is NOT multiplied by the scale factor.
	_sprite.offset = Vector2(0.0, PlayerSpriteFrames.SPRITE_Y_OFFSET_RATIO * float(PlayerSpriteFrames.TILE))


func drawn_height() -> float:
	return _drawn_height


func _ready() -> void:
	z_index = z_order
	z_as_relative = false
	if _sprite == null:
		return
	_sprite.sprite_frames = PlayerSpriteFrames.build()
	_sprite.animation = &"idle"
	# The character art is drawn around its own centre; nudge it so the sprite's
	# feet line up with the bottom of the collision circle.
	_sprite.centered = true
	_sprite.offset = Vector2(0.0, PlayerSpriteFrames.SPRITE_Y_OFFSET_RATIO * float(PlayerSpriteFrames.TILE))
	# Nearest-neighbour: the sheet is pixel art and must not be blurred when the
	# camera is zoomed. Without this the character smears into the background.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play(&"idle")


## Chooses the animation matching the player's current motion.
## Called each physics frame from Player.gd.
func update_animation(is_on_floor: bool) -> void:
	if _sprite == null:
		return

	var wanted := &"idle"
	if not is_on_floor:
		wanted = &"jump"
	elif _is_moving():
		wanted = &"walk"

	if _sprite.animation != wanted:
		_sprite.play(wanted)


## Flips the sprite to face left/right.
func set_facing(direction: Vector2) -> void:
	if _sprite == null or is_zero_approx(direction.x):
		return
	var sign_x := signf(direction.x)
	if is_equal_approx(sign_x, _last_facing_sign):
		return
	_last_facing_sign = sign_x
	_sprite.flip_h = sign_x < 0.0


func _is_moving() -> bool:
	var movement := get_parent().get_node_or_null("MovementComponent") as MovementComponent
	return movement != null and movement.speed() > 4.0


func _draw() -> void:
	# The sprite covers the player; only draw the fallback shape when it is off.
	if use_sprite and _sprite != null and _sprite.sprite_frames != null:
		return
	if config == null:
		return

	# Get colors from skin if equipped, otherwise from config
	var body_color: Color = config.body_color
	var accent_color: Color = config.accent_color
	var visor_color: Color = config.visor_color
	var outline_width: float = config.outline_width

	if skin != null:
		body_color = skin.body_color
		accent_color = skin.accent_color
		visor_color = skin.visor_color
		outline_width = config.outline_width * 2.0

	var r = config.radius * 1.5

	# Body circle - solid filled disc (filled=true is required; a 3-arg
	# draw_circle draws only an unfilled outline and looks hollow on dark floors).
	draw_circle(Vector2.ZERO, r, body_color, -1.0, true)
	# White outline ring: unfilled so the width argument applies.
	draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 1), outline_width * 2.0, false)
	# Inner accent ring, also filled so it reads clearly over the body.
	draw_circle(Vector2.ZERO, r * 0.7, accent_color, -1.0, true)

	# Visor (facing indicator) — a clear triangle in the facing direction.
	var player := get_parent()
	if player != null and player.has_node("MovementComponent"):
		var movement := player.get_node("MovementComponent") as MovementComponent
		if movement != null:
			var facing: Vector2 = movement.facing
			if not facing.is_zero_approx():
				var visor_end_pos: Vector2 = facing * (r * 1.2)
				var perp: Vector2 = Vector2(-facing.y, facing.x) * (r * 0.5)
				draw_polygon([
					Vector2.ZERO,
					visor_end_pos + perp,
					visor_end_pos - perp
				], [visor_color])

	# Debug: draw small center dot
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 1))


func apply_skin(skin_resource: SkinResource) -> void:
	skin = skin_resource
	queue_redraw()


func debug_line() -> String:
	return "Visual"
