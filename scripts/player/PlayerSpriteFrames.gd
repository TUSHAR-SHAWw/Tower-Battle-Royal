class_name PlayerSpriteFrames
extends RefCounted

## Builds the player's SpriteFrames from the Kenney pixel-platformer character
## sheet.
##
## The sheet is a grid of TILE-sized sprites separated by a 1 px gap, i.e. the
## distance between two cells is TILE + GAP. Reading it at a pitch of TILE (as an
## earlier version did) slices 24 px sprites into 18 px windows and walks one pixel
## further out of alignment per column, which decapitated the character: every
## frame showed a helmet with the legs cut off, and the "walk pair" was not even
## the same character.
##
## Frames are built in code (not a hand-authored .tres) so the art can be
## re-pointed by editing the constants below. To swap in your own art, either
## change CHARACTER_SHEET to another uniform grid, or replace this builder with a
## SpriteFrames resource authored in the editor.

const CHARACTER_SHEET := "res://assets/kenney_pixel-platformer/Tilemap/tilemap-characters.png"

## Size of one sprite on the sheet, in pixels. The sheet's own README says 24x24.
const TILE := 24
## Blank pixels between neighbouring sprites on the sheet.
const GAP := 1
## Distance from one cell's origin to the next. Never use TILE for this.
const PITCH := TILE + GAP

## Grid cell of the character used for the player (blue, row 0).
const PLAYER_CELL := Vector2i(2, 0)
## Second cell of the pair — the alternate walk pose.
const PLAYER_CELL_ALT := Vector2i(3, 0)
## Jump pose: one row down, first frame of the pair.
const PLAYER_CELL_JUMP := Vector2i(2, 1)

## Frame rate for the walk cycle (frames per second).
const WALK_FPS := 8.0

## How far the sprite is drawn above its own centre so the feet line up with the
## bottom of the collision circle, as a fraction of the drawn sprite height.
const SPRITE_Y_OFFSET_RATIO := -0.08


## Creates SpriteFrames with idle / walk / jump animations at the sheet's native
## 24x24 size. The drawn size is applied by the caller as a node scale — an
## AtlasTexture has no `scale` property, so baking it here produced null frames.
static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	_add_loop(frames, &"idle", [PLAYER_CELL], 1.0)
	_add_loop(frames, &"walk", [PLAYER_CELL, PLAYER_CELL_ALT], WALK_FPS)
	_add_loop(frames, &"jump", [PLAYER_CELL_JUMP], 1.0)

	return frames


static func _add_loop(frames: SpriteFrames, anim_name: StringName, cells: Array[Vector2i],
		fps: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	for cell in cells:
		frames.add_frame(anim_name, _atlas_texture(cell))


## One TILE-sized region of the character sheet as an AtlasTexture.
static func _atlas_texture(cell: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(CHARACTER_SHEET) as Texture2D
	atlas.region = Rect2(Vector2(cell.x * PITCH, cell.y * PITCH), Vector2(TILE, TILE))
	# `filter_clip` keeps the 1 px gutter from bleeding into the neighbouring cell.
	atlas.filter_clip = true
	return atlas
