class_name PhysicsLayers
extends RefCounted

## Named 2D collision layers.
##
## Why constants instead of magic numbers in scenes/scripts: collision layers are
## invisible at the call site (`collision_mask = 5` tells nobody anything), and a
## wrong mask produces bugs that only show up as "my bullets do not hit".
## Keep this in sync with project.godot's `layer_names/2d_physics/*`.

## Floors, walls, cover.
const WORLD := 1 << 0
## Player bodies.
const PLAYER := 1 << 1
## Bots / AI bodies.
const ENEMY := 1 << 2
## Damageable area of a player.
const PLAYER_HURTBOX := 1 << 3
## Damageable area of a bot.
const ENEMY_HURTBOX := 1 << 4
## Bullets and thrown objects.
const PROJECTILE := 1 << 5
## Loot chests, travel items, buttons.
const INTERACTABLE := 1 << 6
## Dropped pickups.
const LOOT := 1 << 7
## Floor triggers, the central shaft, deletion volumes.
const FLOOR_ZONE := 1 << 8
## Hazards, collapsing floor, spikes.
const ENVIRONMENT := 1 << 9
## AI vision and line-of-sight rays.
const SENSORS := 1 << 10


## Everything that can stop a bullet (used by hitscan in M3).
static func bullet_blockers() -> int:
	return WORLD


## Everything a player body collides with.
static func player_obstacles() -> int:
	return WORLD | ENEMY


## Everything that damages a player (hurtboxes of others + projectiles + zones).
static func player_damage_sources() -> int:
	return ENEMY_HURTBOX | PROJECTILE | FLOOR_ZONE
