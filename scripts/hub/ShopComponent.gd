class_name ShopComponent
extends Node

## Handles shop transactions: buy, sell, buyback.

signal item_bought(item: ItemResource, price: int, remaining_stock: int)
signal item_sold(item: ItemResource, price: int)
signal insufficient_funds(item: ItemResource, price: int)
signal max_stock_reached(item: ItemResource)

@export var inventory: ShopInventory

var _stock: Dictionary = {}  # ShopItem -> current stock

func _ready() -> void:
	_init_stock()


func _init_stock() -> void:
	_stock.clear()
	if inventory == null:
		return
	for item in inventory.items:
		_stock[item] = item.stock


func buy(player: Node, shop_item: ShopItem, count: int = 1) -> bool:
	if inventory == null:
		return false
	
	var available_items := inventory.get_available_items(1, 0)  # simplified
	if not available_items.has(shop_item):
		return false
	
	var total_price: int = shop_item.price * count
	var player_gold: int = _get_player_gold(player)
	if player_gold < total_price:
		insufficient_funds.emit(shop_item.item, total_price)
		return false
	
	var current_stock: int = _stock.get(shop_item, shop_item.stock)
	if current_stock >= 0 and current_stock < count:
		max_stock_reached.emit(shop_item.item)
		return false
	
	# Process purchase
	_set_player_gold(player, player_gold - total_price)
	
	var inv := player.get_node_or_null("InventoryComponent")
	if inv != null:
		inv.add_item(shop_item.item, count)
	
	if current_stock >= 0:
		_stock[shop_item] = current_stock - count
	
	item_bought.emit(shop_item.item, total_price, _stock.get(shop_item, shop_item.stock))
	SignalHub.item_bought.emit(shop_item.item, total_price)
	return true


func sell(player: Node, item: ItemResource, count: int = 1) -> bool:
	if inventory == null:
		return false
	
	var inv := player.get_node_or_null("InventoryComponent")
	if inv == null or inv.get_item_count(item.item_id) < count:
		return false
	
	# Find shop item for this item
	var shop_item: ShopItem = null
	for si in inventory.items:
		if si.item != null and si.item.item_id == item.item_id:
			shop_item = si
			break
	
	var price: int
	if shop_item != null:
		price = int(shop_item.price * inventory.buyback_multiplier)
	else:
		# Generic buyback at 25% of estimated value
		price = max(1, int((item.max_stack * 10) * 0.25))
	
	var total_price := price * count
	
	# Process sale
	inv.remove_item(item.item_id, count)
	_set_player_gold(player, _get_player_gold(player) + total_price)
	
	item_sold.emit(item, total_price)
	SignalHub.item_sold.emit(item, total_price)
	return true


func get_shop_items(floor: int, reputation: int) -> Array[ShopItem]:
	if inventory == null:
		return []
	return inventory.get_available_items(floor, reputation)


func get_stock(shop_item: ShopItem) -> int:
	return _stock.get(shop_item, shop_item.stock)


func _get_player_gold(player: Node) -> int:
	# Check for currency component or gold variable
	if player.has_method("get_gold"):
		return player.get_gold()
	var inv := player.get_node_or_null("InventoryComponent")
	if inv != null:
		return inv.get_item_count(&"gold")
	return 0


func _set_player_gold(player: Node, amount: int) -> void:
	if player.has_method("set_gold"):
		player.set_gold(amount)
		return
	var inv: InventoryComponent = player.get_node_or_null("InventoryComponent")
	if inv != null:
		# Use a gold item
		var current: int = inv.get_item_count(&"gold")
		if amount >= current:
			inv.add_item(load("res://resources/items/gold.tres") as ItemResource, amount - current)
		else:
			inv.remove_item(&"gold", current - amount)