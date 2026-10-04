class_name ShopController
extends Area2D

## Side-room controller: a small alcove attached to a floor's side wall, with a
## counter and a vendor. The player walks in (detected via Area2D) and can press
## Interact to open a shop panel.

signal shop_opened(player: Node)
signal shop_closed()

@export var theme: FloorTheme = null
@export var shop_items: Array[String] = ["health_pack", "adrenaline", "knife"]

var _open: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	# Detect the player's hurtbox (layer PLAYER_HURTBOX) as well as the body.
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PLAYER_HURTBOX
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	# The detected node is usually the Hurtbox; climb to the player root.
	var node: Node = area
	while node != null:
		if node.is_in_group(&"player"):
			SignalHub.hud_notification.emit("Side Room - Interact to open", &"info")
			return
		node = node.get_parent()


func open_for(player: Node) -> void:
	_open = true
	shop_opened.emit(player)


func close() -> void:
	_open = false
	shop_closed.emit()


func is_open() -> bool:
	return _open