class_name InventoryComponent
extends Node

## Slot-based inventory component. Handles add/remove/swap/use of items.
## Designed to be attached to Player.

signal item_added(item_id: StringName, slot_index: int)
signal item_removed(item_id: StringName, slot_index: int)
signal item_swapped(from_slot: int, to_slot: int)
signal hotbar_changed(active_slot: int)
signal item_used(item_id: StringName)

## Number of hotbar slots (index 0..8)
const HOTBAR_SIZE := 9
## Total inventory size (hotbar + backpack)
const BACKPACK_SIZE := 18
const TOTAL_SIZE := HOTBAR_SIZE + BACKPACK_SIZE

## A slot in the inventory.
class InventorySlot:
	var item: ItemResource = null
	var quantity: int = 0
	
	func is_empty() -> bool:
		return item == null
	
	func can_add(new_item: ItemResource) -> bool:
		if item == null:
			return true
		if item.item_id == new_item.item_id:
			return quantity < item.max_stack
		return false
	
	func add(new_item: ItemResource, count: int = 1) -> int:
		if item == null:
			item = new_item
			quantity = count
			return count
		if item.item_id == new_item.item_id:
			var space: int = item.max_stack - quantity
			var added: int = min(space, count)
			quantity += added
			return added
		return 0
	
	func remove(count: int = 1) -> int:
		var removed: int = min(quantity, count)
		quantity -= removed
		if quantity <= 0:
			item = null
			quantity = 0
		return removed

var _slots: Array[InventorySlot] = []
var _active_slot: int = 0
var _grid_enabled: bool = true  # grid-style pickup (auto-stacks)

func _ready() -> void:
	# Initialize all slots
	for i in range(TOTAL_SIZE):
		_slots.append(InventorySlot.new())


func get_active_slot() -> int:
	return _active_slot


func get_slot(index: int) -> InventorySlot:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func get_active_item() -> ItemResource:
	return _slots[_active_slot].item


func get_active_quantity() -> int:
	return _slots[_active_slot].quantity


func set_active_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	_active_slot = index
	hotbar_changed.emit(_active_slot)


func _find_partial_stack(item: ItemResource) -> int:
	for i in range(TOTAL_SIZE):
		var slot := _slots[i]
		if not slot.is_empty() and slot.item.item_id == item.item_id and slot.quantity < slot.item.max_stack:
			return i
	return -1


func add_item(item: ItemResource, count: int = 1) -> int:
	if item == null:
		return 0
	
	# Try to add to existing stack
	if _grid_enabled:
		var existing_slot := _find_partial_stack(item)
		if existing_slot >= 0:
			var added := _slots[existing_slot].add(item, count)
			if added > 0:
				item_added.emit(item.item_id, existing_slot)
				if _is_hotbar_slot(existing_slot):
					item_added.emit(item.item_id, existing_slot)
				return added
	
	# Find empty slot
	for i in range(HOTBAR_SIZE, TOTAL_SIZE):
		var slot := _slots[i]
		if slot.is_empty():
			var added := slot.add(item, count)
			if added > 0:
				item_added.emit(item.item_id, i)
				return added
	
	# Try hotbar first if it's a new item type
	if _grid_enabled:
		for i in range(HOTBAR_SIZE):
			var slot := _slots[i]
			if slot.is_empty():
				var added := slot.add(item, count)
				if added > 0:
					item_added.emit(item.item_id, i)
					return added
	
	return 0


func remove_item_from_slot(slot_index: int, count: int = 1) -> int:
	if slot_index < 0 or slot_index >= _slots.size():
		return 0
	var removed := _slots[slot_index].remove(count)
	if removed > 0:
		item_removed.emit(_slots[slot_index].item.item_id if _slots[slot_index].item != null else &"empty", slot_index)
	return removed


func remove_item(item_id: StringName, count: int = 1) -> int:
	var total_removed := 0
	for i in range(_slots.size()):
		var slot := _slots[i]
		if not slot.is_empty() and slot.item.item_id == item_id:
			total_removed += remove_item_from_slot(i, count - total_removed)
			if total_removed >= count:
				break
	return total_removed


func swap_slots(from: int, to: int) -> bool:
	if from < 0 or from >= _slots.size() or to < 0 or to >= _slots.size():
		return false
	
	var temp_item: ItemResource = _slots[from].item
	_slots[from].item = _slots[to].item
	_slots[to].item = temp_item
	
	var temp_qty: int = _slots[from].quantity
	_slots[from].quantity = _slots[to].quantity
	_slots[to].quantity = temp_qty
	
	item_swapped.emit(from, to)
	return true


func use_active_item() -> bool:
	var item := get_active_item()
	if item == null:
		return false
	
	item_used.emit(item.item_id)
	SignalHub.item_used.emit(item.item_id)
	
	if item.is_consumable:
		remove_item_from_slot(_active_slot, 1)
	
	return true


func get_item_count(item_id: StringName) -> int:
	var total := 0
	for slot in _slots:
		if slot.item != null and slot.item.item_id == item_id:
			total += slot.quantity
	return total


func _is_hotbar_slot(index: int) -> bool:
	return index >= 0 and index < HOTBAR_SIZE


func get_hotbar_items() -> Array[ItemResource]:
	var items: Array[ItemResource] = []
	for i in range(HOTBAR_SIZE):
		items.append(_slots[i].item)
	return items


func debug_line() -> String:
	return "inv: %d/%d slots active=%d" % [_count_non_empty(), TOTAL_SIZE, _active_slot]


func _count_non_empty() -> int:
	var count := 0
	for slot in _slots:
		if slot.item != null:
			count += 1
	return count