class_name UpgradeStation
extends Node

## Handles weapon/gear upgrades using materials and gold.

signal upgrade_started(item: ItemResource, tier: int)
signal upgrade_completed(item: ItemResource, new_tier: int, success: bool)
signal upgrade_failed(item: ItemResource, tier: int, reason: StringName)

@export var upgrade_recipes: Array = []

var _upgrading: bool = false
var _current_item: ItemResource = null
var _target_tier: int = 0


func _ready() -> void:
	pass


func can_upgrade(item: ItemResource, target_tier: int, inventory: InventoryComponent) -> bool:
	if item == null or not item.is_equippable:
		return false
	if item.weapon_resource == null and item.melee_resource == null:
		return false
	
	var current_tier: int = item.tier
	if target_tier <= current_tier:
		return false
	
	# Check recipe
	var recipe := _find_recipe(item, target_tier)
	if recipe == null:
		return false
	
	return _has_materials(recipe, inventory)


func start_upgrade(item: ItemResource, target_tier: int, inventory: InventoryComponent) -> bool:
	if _upgrading:
		return false
	if not can_upgrade(item, target_tier, inventory):
		upgrade_failed.emit(item, target_tier, &"cannot_upgrade")
		return false
	
	var recipe := _find_recipe(item, target_tier)
	if recipe == null:
		upgrade_failed.emit(item, target_tier, &"no_recipe")
		return false
	
	# Consume materials
	_consume_materials(recipe, inventory)
	
	_upgrading = true
	_current_item = item
	_target_tier = target_tier
	
	upgrade_started.emit(item, target_tier)
	return true


func cancel_upgrade(inventory: InventoryComponent) -> void:
	if not _upgrading:
		return
	
	# Refund materials
	if _current_item != null and _target_tier > 0:
		var recipe := _find_recipe(_current_item, _target_tier)
		if recipe != null:
			_refund_materials(recipe, inventory)
	
	_upgrading = false
	_current_item = null
	_target_tier = 0


func _physics_process(delta: float) -> void:
	if not _upgrading:
		return
	
	# Upgrade takes time
	# In a real implementation, you'd have a timer
	_finish_upgrade()


func _finish_upgrade() -> void:
	if not _upgrading:
		return
	
	var success := true  # Could add failure chance
	
	if success and _current_item != null:
		# Apply upgrade
		if _current_item.has_tier():
			_current_item.tier = _target_tier
		else:
			_current_item.tier = _target_tier
	
	upgrade_completed.emit(_current_item, _target_tier, success)
	SignalHub.item_upgraded.emit(_current_item, _target_tier, success)
	
	_upgrading = false
	_current_item = null
	_target_tier = 0


func _find_recipe(item: ItemResource, target_tier: int) -> UpgradeRecipe:
	for recipe in upgrade_recipes:
		if recipe.base_item == item and recipe.target_tier == target_tier:
			return recipe
	return null


func _has_materials(recipe: UpgradeRecipe, inventory: InventoryComponent) -> bool:
	for req in recipe.materials:
		if inventory.get_item_count(req.item.item_id) < req.count:
			return false
	return true


func _consume_materials(recipe: UpgradeRecipe, inventory: InventoryComponent) -> void:
	for req in recipe.materials:
		inventory.remove_item(req.item.item_id, req.count)


func _refund_materials(recipe: UpgradeRecipe, inventory: InventoryComponent) -> void:
	for req in recipe.materials:
		inventory.add_item(req.item, req.count)


class UpgradeRecipe:
	var base_item: ItemResource
	var target_tier: int
	var materials: Array[UpgradeMaterial] = []
	var gold_cost: int = 0
	var success_chance: float = 1.0


class UpgradeMaterial:
	var item: ItemResource
	var count: int