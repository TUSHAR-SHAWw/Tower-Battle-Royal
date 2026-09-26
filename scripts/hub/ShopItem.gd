class_name ShopItem
extends Resource

## An item available for purchase in a shop.

@export var item: ItemResource
@export var price: int = 100
@export var stock: int = -1  # -1 = unlimited
@export var min_floor: int = 1  # only available from this floor onward
@export var required_reputation: int = 0

func validate() -> Array[String]:
	var problems: Array[String] = []
	if item == null:
		problems.append("item required")
	if price < 0:
		problems.append("price must be >= 0")
	return problems


func can_buy(player_floor: int, player_reputation: int, current_stock: int) -> bool:
	if player_floor < min_floor:
		return false
	if player_reputation < required_reputation:
		return false
	if stock >= 0 and current_stock <= 0:
		return false
	return true