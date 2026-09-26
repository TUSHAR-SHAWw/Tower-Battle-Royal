class_name CraftingStation
extends Node

## Handles crafting items from materials using recipes.

signal crafting_started(recipe: CraftingRecipe)
signal crafting_completed(recipe: CraftingRecipe, success: bool, output: ItemResource)
signal crafting_failed(recipe: CraftingRecipe, reason: StringName)

@export var recipes: Array = []

var _crafting: bool = false
var _current_recipe: CraftingRecipe = null


func _ready() -> void:
	pass


func can_craft(recipe: CraftingRecipe, inventory: InventoryComponent) -> bool:
	if recipe == null or inventory == null:
		return false
	for req in recipe.inputs:
		if inventory.get_item_count(req.item.item_id) < req.count:
			return false
	return true


func start_craft(recipe: CraftingRecipe, inventory: InventoryComponent) -> bool:
	if _crafting:
		return false
	if not can_craft(recipe, inventory):
		crafting_failed.emit(recipe, &"insufficient_materials")
		return false
	
	# Consume inputs
	for req in recipe.inputs:
		inventory.remove_item(req.item.item_id, req.count)
	
	_crafting = true
	_current_recipe = recipe
	
	crafting_started.emit(recipe)
	return true


func cancel_craft(inventory: InventoryComponent) -> void:
	if not _crafting:
		return
	
	# Refund inputs
	if _current_recipe != null:
		for req in _current_recipe.inputs:
			inventory.add_item(req.item, req.count)
	
	_crafting = false
	_current_recipe = null


func _physics_process(delta: float) -> void:
	if not _crafting:
		return
	
	# Crafting takes time
	_finish_craft()


func _finish_craft() -> void:
	if not _crafting:
		return
	
	var success := randf() < _current_recipe.success_chance
	var output: ItemResource = null
	
	if success:
		output = _current_recipe.output_item
	else:
		# Partial refund on failure
		for req in _current_recipe.inputs:
			var refund_count := int(req.count * 0.5)
			if refund_count > 0:
				# Would need inventory reference here
				pass
	
	crafting_completed.emit(_current_recipe, success, output)
	SignalHub.item_crafted.emit(_current_recipe, success, output)
	
	_crafting = false
	_current_recipe = null


func get_craft_progress() -> float:
	if not _crafting:
		return 0.0
	return 1.0  # Instant for now


class CraftingRecipe:
	var output_item: ItemResource
	var inputs: Array[CraftingInput] = []
	var craft_time: float = 1.0
	var success_chance: float = 1.0
	var required_station: StringName = &""


class CraftingInput:
	var item: ItemResource
	var count: int