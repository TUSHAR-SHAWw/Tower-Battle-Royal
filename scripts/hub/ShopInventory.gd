class_name ShopInventory
extends Resource

## A shop's inventory of items for sale.

@export var shop_name: String = "Unnamed Shop"
@export var items: Array[ShopItem] = []
@export var buyback_multiplier: float = 0.5  # fraction of price when selling to shop

func get_available_items(floor: int, reputation: int) -> Array[ShopItem]:
	var result: Array[ShopItem] = []
	for item in items:
		if item.can_buy(floor, reputation, item.stock):
			result.append(item)
	return result