class_name MergeComponent
extends Node

## Handles item merging at merge stations / central hub.

signal merge_started(recipe: MergeRecipe)
signal merge_completed(recipe: MergeRecipe, success: bool, output: ItemResource)
signal merge_failed(recipe: MergeRecipe, reason: StringName)

@export var available_recipes: Array[MergeRecipe] = []

var _is_merging: bool = false
var _current_recipe: MergeRecipe = null
var _merge_timer: float = 0.0

func _ready() -> void:
	pass


func can_merge(recipe: MergeRecipe, inventory: InventoryComponent) -> bool:
	if recipe == null or inventory == null:
		return false
	if inventory.get_item_count(recipe.input_item.item_id) < recipe.input_count:
		return false
	# Could check gold cost here
	return true


func start_merge(recipe: MergeRecipe, inventory: InventoryComponent) -> bool:
	if _is_merging:
		merge_failed.emit(recipe, &"busy")
		return false
	if not can_merge(recipe, inventory):
		merge_failed.emit(recipe, &"insufficient_items")
		return false
	
	_is_merging = true
	_current_recipe = recipe
	_merge_timer = 0.0
	
	# Consume input items
	inventory.remove_item(recipe.input_item.item_id, recipe.input_count)
	
	merge_started.emit(recipe)
	SignalHub.merge_started.emit(recipe)
	return true


func cancel_merge(inventory: InventoryComponent) -> void:
	if not _is_merging:
		return
	
	# Refund input items
	if _current_recipe != null and inventory != null:
		inventory.add_item(_current_recipe.input_item, _current_recipe.input_count)
	
	_is_merging = false
	_current_recipe = null
	_merge_timer = 0.0
	merge_failed.emit(_current_recipe, &"cancelled")


func _physics_process(delta: float) -> void:
	if not _is_merging or _current_recipe == null:
		return
	
	_merge_timer += delta
	if _merge_timer >= 2.0:  # merge takes 2 seconds
		_finish_merge()
		_merge_timer = 0.0


func _finish_merge() -> void:
	var success := randf() < _current_recipe.success_chance
	var output: ItemResource = null
	
	if success:
		output = _current_recipe.output_item
	else:
		output = _current_recipe.input_item  # refund one on fail
	
	merge_completed.emit(_current_recipe, success, output)
	SignalHub.merge_completed.emit(_current_recipe, success, output)
	
	_is_merging = false
	_current_recipe = null
	_merge_timer = 0.0


func get_merge_progress() -> float:
	if not _is_merging:
		return 0.0
	return clamp(_merge_timer / 2.0, 0.0, 1.0)


func get_active_recipe() -> MergeRecipe:
	return _current_recipe