class_name LootTable
extends Resource

## Defines weighted loot drops for chests / enemies.

@export var entries: Array = []


func roll() -> Array[LootResult]:
	var results: Array[LootResult] = []
	for entry in entries:
		if randf() < entry.chance:
			var count := randi_range(entry.min_count, entry.max_count + 1)
			results.append(LootResult.new(entry.item, count))
	return results


func roll_guaranteed(min_items: int = 1) -> Array:
	var results := roll()
	while results.size() < min_items and entries.size() > 0:
		var entry: Dictionary = entries.pick_random()
		var count: int = randi_range(entry.min_count, entry.max_count + 1)
		results.append(LootResult.new(entry.item, count))
	return results


class LootEntry:
	var item: ItemResource
	var chance: float = 1.0      # 0.0-1.0
	var min_count: int = 1
	var max_count: int = 1


class LootResult:
	var item: ItemResource
	var count: int
	
	func _init(p_item: ItemResource, p_count: int):
		item = p_item
		count = p_count