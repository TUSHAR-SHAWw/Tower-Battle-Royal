class_name Enemy
extends CharacterBody2D

## Base enemy actor. Composed of AI, movement, health, visuals.
##
## Damage reaches this actor through the Hurtbox Area2D (collision_layer
## ENEMY_HURTBOX) rather than through the body, so projectiles and melee can
## resolve the owner with take_damage(). See MeleeHitbox/Bullet `_resolve_target`.

signal died(killer: Node)

@export var enemy_data: EnemyResource

@onready var ai: EnemyAI = $EnemyAI
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var visual: Node2D = $Visual


func _ready() -> void:
	# EnemyAI and LootChest look actors up by group, so register here.
	add_to_group(&"enemies")

	# Physics layers: enemy body, colliding with world geometry and other actors.
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.ENEMY

	if enemy_data != null:
		health.max_health = enemy_data.max_health
		health.current_health = enemy_data.max_health
		movement.max_speed = enemy_data.move_speed

	if ai != null:
		ai.enemy_data = enemy_data
		if not ai.died.is_connected(_on_ai_died):
			ai.died.connect(_on_ai_died)

	if visual != null and enemy_data != null:
		# `enemy_data` was dereferenced without a null check before, so an enemy
		# spawned without a resource crashed on _ready().
		var scale_factor: float = enemy_data.size / 16.0
		visual.scale = Vector2(scale_factor, scale_factor)


## Damage entry point used by Bullet and MeleeComponent via the hurtbox.
func take_damage(info: DamageInfo) -> float:
	if health == null:
		return 0.0
	return health.apply_damage(info)


func _on_ai_died(killer: Node) -> void:
	died.emit(killer)
	# EnemySpawner listens to EnemyAI.died, but everything else (HUD, economy,
	# kill credit) listens to the bus, so the fact is published here once.
	SignalHub.enemy_died.emit(self, killer)
	queue_free()
