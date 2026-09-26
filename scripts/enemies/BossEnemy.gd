class_name BossEnemy
extends CharacterBody2D

## Boss enemy with multiple phases.

signal phase_changed(phase: int)
signal died(killer: Node)

@export var boss_data: BossData

var _phase: int = 1
var _phase_health_thresholds: Array[float] = [0.75, 0.5, 0.25]
var _phase_behaviors: Array[Callable] = []
var _ai: BossAI = null
var _health: HealthComponent = null

func _ready() -> void:
	_health = get_node_or_null("HealthComponent")
	_ai = get_node_or_null("BossAI")
	
	if boss_data != null and _health != null:
		_health.max_health = boss_data.max_health
		_health.current_health = boss_data.max_health
	
	if _ai != null:
		_ai.boss_data = boss_data
		_ai.phase_changed.connect(_on_boss_ai_phase_changed)
	
	if _health != null:
		_health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if _phase == 0:
		return
	
	_check_phase_transition()


func _check_phase_transition() -> void:
	if boss_data == null or _health == null:
		return
	
	var hp_ratio := _health.current_health / _health.max_health
	var target_phase := 1
	
	for i in range(_phase_health_thresholds.size()):
		if hp_ratio <= _phase_health_thresholds[i]:
			target_phase = i + 2
	
	if target_phase != _phase and target_phase <= boss_data.phases.size():
		_transition_to_phase(target_phase)


func _transition_to_phase(new_phase: int) -> void:
	_phase = new_phase
	phase_changed.emit(_phase)
	SignalHub.boss_phase_changed.emit(self, _phase)
	
	# Apply phase modifiers
	if boss_data != null and _phase <= boss_data.phases.size():
		var phase_data := boss_data.phases[_phase - 1]
		_apply_phase(phase_data)


func _apply_phase(phase_data: BossPhaseData) -> void:
	# Could modify stats, add new attacks, change visuals
	pass


func _on_died(info: DamageInfo) -> void:
	died.emit(info.source)
	SignalHub.boss_died.emit(self, info.source)
	queue_free()


func _on_boss_ai_phase_changed(phase: int) -> void:
	# AI reports phase change, sync our phase
	_phase = phase


func get_phase() -> int:
	return _phase