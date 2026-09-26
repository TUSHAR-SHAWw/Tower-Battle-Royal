class_name SkinResource
extends Resource

## Cosmetic skin configuration. Lives in `resources/skins/*.tres`.
## Purely visual - no gameplay effect.

@export_group("Identity")
@export var skin_name: String = "Unnamed Skin"
@export var skin_id: StringName = &"default"
@export var description: String = ""

@export_group("Rarity")
@export var rarity: Rarity = Rarity.COMMON
@export var unlock_cost: int = 0  # gold cost to unlock
@export var is_default: bool = false

@export_group("Visual Overrides")
## Applied to VisualComponent when equipped
@export var body_color: Color = Color(1, 1, 1, 1)
@export var accent_color: Color = Color(1, 1, 1, 1)
@export var trail_color: Color = Color(1, 1, 1, 1)
@export var particle_color: Color = Color(1, 1, 1, 1)

@export_group("Special Effects")
@export var has_glow: bool = false
@export var glow_color: Color = Color(1, 1, 1, 0.3)
@export var has_trail: bool = false

enum Rarity {
	COMMON = 0,      # White
	UNCOMMON = 1,    # Green
	RARE = 2,        # Blue
	EPIC = 3,        # Purple
	LEGENDARY = 4,   # Gold
	MYTHIC = 5       # Rainbow/animated
}

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.7, 1)
		Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2, 1)
		Rarity.RARE: return Color(0.2, 0.5, 1.0, 1)
		Rarity.EPIC: return Color(0.7, 0.2, 1.0, 1)
		Rarity.LEGENDARY: return Color(1.0, 0.8, 0.1, 1)
		Rarity.MYTHIC: return Color(1.0, 0.2, 0.8, 1)
	return Color(1, 1, 1, 1)


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.MYTHIC: return "Mythic"
	return "Unknown"


func validate() -> Array[String]:
	var problems: Array[String] = []
	if skin_name.is_empty():
		problems.append("skin_name cannot be empty")
	if skin_id == &"default" and not is_default:
		problems.append("skin_id should not be 'default' for non-default skins")
	if unlock_cost < 0:
		problems.append("unlock_cost must be >= 0")
	return problems