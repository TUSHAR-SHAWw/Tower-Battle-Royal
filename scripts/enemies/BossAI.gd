class_name BossAI
extends Node

## Boss AI with phase-based behavior.

signal phase_changed(phase: int)

@export var boss_data: BossData

var _boss: BossEnemy = null
var _current_phase: int = 1

func _ready() -> void:
	_boss = get_parent() as BossEnemy
	
	if boss_data != null:
		# Initialize with phase 1
		_current_phase = 1


func set_phase(phase: int) -> void:
	if phase < 1 or (boss_data != null and phase > boss_data.phases.size()):
		return
	
	_current_phase = phase
	phase_changed.emit(_current_phase)
	
	if _boss != null:
		_boss._transition_to_phase(phase)


func get_current_phase() -> int:
	return _current_phase


func get_phase_data() -> BossPhaseData:
	if boss_data != null and _current_phase <= boss_data.phases.size():
		return boss_data.phases[_current_phase - 1]
	return null