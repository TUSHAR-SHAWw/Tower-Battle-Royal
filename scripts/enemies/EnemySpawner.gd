class_name EnemySpawner
extends Node

## Spawns enemies in waves, scaled by floor.

signal wave_started(wave: int)
signal wave_completed(wave: int)
signal enemy_spawned(enemy: Node)
signal all_waves_completed()

@export var floor_controller: Node = null
@export var enemy_types: Array[EnemyResource] = []
@export var base_wave_count: int = 3
@export var enemies_per_wave: int = 5
@export var wave_interval: float = 10.0
@export var spawn_radius: float = 400.0

var _current_wave: int = 0
var _enemies_alive: int = 0
var _wave_timer: float = 0.0
var _spawning: bool = false
var _floor: int = 1

func _ready() -> void:
	pass


func start_spawning(floor: int) -> void:
	_floor = floor
	_current_wave = 0
	_enemies_alive = 0
	_spawning = true
	_wave_timer = 0.0
	_start_next_wave()


func stop_spawning() -> void:
	_spawning = false


func _physics_process(delta: float) -> void:
	if not _spawning:
		return
	
	if _enemies_alive <= 0 and _current_wave > 0:
		_wave_timer += delta
		if _wave_timer >= wave_interval:
			_start_next_wave()
			_wave_timer = 0.0


func _start_next_wave() -> void:
	_current_wave += 1
	
	if _current_wave > base_wave_count:
		_spawning = false
		all_waves_completed.emit()
		return
	
	wave_started.emit(_current_wave)
	SignalHub.wave_started.emit(_current_wave)
	
	var count := enemies_per_wave + _current_wave - 1
	
	for i in range(count):
		call_deferred("_spawn_enemy", i * 0.5)


func _spawn_enemy(delay: float) -> void:
	if not _spawning:
		return
	
	var enemy_type := _pick_enemy_type()
	if enemy_type == null:
		return
	
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var enemy := enemy_scene.instantiate() as Enemy
	
	if floor_controller != null and floor_controller.has_method("get_current_floor"):
		var floor: Node = floor_controller.get_current_floor()
		if floor != null:
			enemy.global_position = _get_spawn_position(floor)
	
	# Apply floor scaling
	var scaled := enemy_type.get_scaled_stats(_floor)
	enemy.health.max_health = scaled.max_health
	enemy.health.current_health = scaled.max_health
	enemy.movement.max_speed = scaled.move_speed
	
	enemy.enemy_data = enemy_type
	
	var ai := enemy.get_node_or_null("EnemyAI")
	if ai != null:
		ai.enemy_data = enemy_type
		ai.died.connect(_on_enemy_died)
	
	get_parent().add_child(enemy)
	_enemies_alive += 1
	enemy_spawned.emit(enemy)
	SignalHub.enemy_spawned.emit(enemy)


func _get_spawn_position(floor: Node) -> Vector2:
	var bounds: Rect2 = floor.floor_data.bounds if floor.floor_data != null else Rect2(-1000, -1000, 2000, 2000)
	var center: Vector2 = bounds.position + bounds.size * 0.5
	
	# Spawn around edges
	var angle := randf() * TAU
	var dist := spawn_radius * randf_range(0.7, 1.0)
	return center + Vector2(cos(angle), sin(angle)) * dist


func _pick_enemy_type() -> EnemyResource:
	if enemy_types.is_empty():
		return null
	
	# Weighted random based on floor
	var weights: Array[float] = []
	for et in enemy_types:
		var w := 1.0
		if et.enemy_id == &"grunt":
			w = 1.0 - _floor * 0.05
		elif et.enemy_id == &"sniper":
			w = _floor * 0.1
		weights.append(max(0.1, w))
	
	var total := 0.0
	for w in weights:
		total += w
	
	var r := randf() * total
	var sum := 0.0
	for i in range(enemy_types.size()):
		sum += weights[i]
		if r <= sum:
			return enemy_types[i]
	
	return enemy_types[0]


func _on_enemy_died(killer: Node) -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	
	# Grant rewards to killer
	if killer != null:
		var currency := killer.get_node_or_null("CurrencyComponent")
		var inventory := killer.get_node_or_null("InventoryComponent")
		
		if currency != null:
			currency.add_xp(25 + _floor * 5)
			currency.add_gold(10 + _floor * 2)
		
		if inventory != null:
			# Chance to drop loot
			if randf() < 0.3:
				var item_id: StringName = ["health_pack", "adrenaline"].pick_random()
				var item := load("res://resources/items/%s.tres" % item_id)
				if item != null:
					inventory.add_item(item, 1)


func get_enemies_alive() -> int:
	return _enemies_alive


func get_current_wave() -> int:
	return _current_wave