class_name ItemResource
extends Resource

## Generic item configuration. Lives in `resources/items/*.tres`.
## Can represent weapons, consumables, materials, quest items.
##
## Values are PROTOTYPE DEFAULTS — not final balance.

@export_group("Identity")
@export var item_name: String = "Unnamed Item"
@export var item_id: StringName = &"unknown"
@export var description: String = ""

@export_group("Visuals")
@export var icon_texture: Texture2D
@export var icon_color: Color = Color(1, 1, 1, 1)

@export_group("Properties")
@export var max_stack: int = 1
@export var is_consumable: bool = false
@export var is_equippable: bool = false
@export var equip_slot: StringName = &""  # "gun", "melee", "armor", etc.
@export var tier: int = 0  # upgrade tier

@export_group("Weapon Stats (if equippable to gun/melee)")
@export var weapon_type: StringName = &""  # "gun" or "melee" or "" for non-weapon items
@export var weapon_resource: WeaponResource  # for gun-type items
@export var melee_resource: MeleeWeaponResource  # for melee-type items

@export_group("Consumable Stats (if consumable)")
@export var effect_type: StringName = &""  # "heal", "speed", "rage", etc.
@export var effect_amount: float = 0.0
@export var effect_duration: float = 0.0

## Returns the list of problems with this configuration (empty means valid).
func validate() -> Array[String]:
	var problems: Array[String] = []
	if item_name.is_empty():
		problems.append("item_name cannot be empty")
	if item_id == &"unknown":
		problems.append("item_id should be set (got 'unknown')")
	if max_stack < 1:
		problems.append("max_stack must be >= 1 (got %d)" % max_stack)
	return problems