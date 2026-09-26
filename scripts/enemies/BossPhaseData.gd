class_name BossPhaseData
extends Resource

## Configuration for a single boss phase.

@export var name: String = "Phase"
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var new_abilities: Array[String] = []  # ability IDs to unlock
@export var visual_overlay_color: Color = Color(1, 1, 1, 0)
@export var arena_modifier: StringName = &""  # e.g. &"add_hazards"