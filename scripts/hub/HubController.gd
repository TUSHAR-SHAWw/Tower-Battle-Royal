class_name HubController
extends Node

## Manages the central hub: shops, upgrade stations, crafting, services.

signal hub_entered(player: Node)
signal hub_exited(player: Node)
signal service_used(service_id: StringName, player: Node)

@export var hub_name: String = "Central Platform"
@export var services: Array = []

var _players_in_hub: Array[Node] = []


func _ready() -> void:
	pass


func on_player_entered(player: Node) -> void:
	if _players_in_hub.has(player):
		return
	_players_in_hub.append(player)
	hub_entered.emit(player)
	SignalHub.hub_entered.emit(player)


func on_player_exited(player: Node) -> void:
	_players_in_hub.erase(player)
	hub_exited.emit(player)
	SignalHub.hub_exited.emit(player)


func get_service(service_id: StringName) -> HubService:
	for svc in services:
		if svc.service_id == service_id:
			return svc
	return null


func use_service(player: Node, service_id: StringName) -> bool:
	var svc := get_service(service_id)
	if svc == null:
		return false
	if not svc.can_use(player):
		return false
	
	svc.use(player)
	service_used.emit(service_id, player)
	SignalHub.hub_service_used.emit(service_id, player)
	return true


class HubService:
	var service_id: StringName
	var display_name: String
	var description: String
	var cost: int = 0
	var cooldown: float = 0.0
	
	func can_use(player: Node) -> bool:
		return true
	
	func use(player: Node) -> void:
		pass