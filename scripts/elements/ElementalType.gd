class_name ElementalType
extends Resource

## Defines an element (fire, ice, lightning, poison) and its interactions.
## Lives in `resources/elements/*.tres`.

@export_group("Identity")
@export var element_name: String = "Unknown"
@export var element_id: StringName = &"none"
@export var color: Color = Color(1, 1, 1, 1)

@export_group("Status Effect")
@export var status_effect_id: StringName = &""  # e.g. &"burn", &"freeze"
@export var status_dps: float = 5.0
@export var status_duration: float = 5.0
@export var status_tick_interval: float = 1.0

@export_group("Damage Modifiers vs Other Elements")
## 1.0 = normal, >1.0 = strong against, <1.0 = weak against
@export var vs_fire: float = 1.0
@export var vs_ice: float = 1.0
@export var vs_lightning: float = 1.0
@export var vs_poison: float = 1.0
@export var vs_physical: float = 1.0

@export_group("Visuals")
@export var particle_color: Color = Color(1, 1, 1, 1)
@export var screen_flash_color: Color = Color(1, 1, 1, 0.3)

## Returns damage multiplier against another element.
func get_multiplier_vs(other_id: StringName) -> float:
	match other_id:
		&"fire": return vs_fire
		&"ice": return vs_ice
		&"lightning": return vs_lightning
		&"poison": return vs_poison
		_ : return vs_physical


func validate() -> Array[String]:
	var problems: Array[String] = []
	if element_name.is_empty():
		problems.append("element_name cannot be empty")
	if element_id == &"none":
		problems.append("element_id should be set")
	return problems