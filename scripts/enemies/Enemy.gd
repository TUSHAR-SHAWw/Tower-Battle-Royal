class_name Enemy
extends CharacterBody2D

## Base enemy actor. Composed of AI, movement, health, visuals.

@export var enemy_data: EnemyResource

signal died(killer: Node)

@onready var ai: EnemyAI = $EnemyAI
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var visual: Node2D = $Visual

func _ready() -> void:
	if enemy_data != null:
		health.max_health = enemy_data.max_health
		health.current_health = enemy_data.max_health
		movement.max_speed = enemy_data.move_speed
	
	if ai != null:
		ai.enemy_data = enemy_data
		ai.died.connect(_on_ai_died)
	
	if visual != null:
		visual.scale = Vector2(enemy_data.size / 16.0, enemy_data.size / 16.0)


func _on_ai_died(killer: Node) -> void:
	died.emit(killer)
	queue_free()