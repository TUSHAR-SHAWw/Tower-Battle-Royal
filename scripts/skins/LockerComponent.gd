class_name LockerComponent
extends Node

## Manages owned skins and equipped skin.

signal skin_equipped(skin: SkinResource)
signal skin_unequipped(skin: SkinResource)
signal skin_unlocked(skin: SkinResource)
signal skin_locked(skin: SkinResource)

@export var owned_skins: Array[SkinResource] = []
@export var equipped_skin: SkinResource = null

var _default_skin: SkinResource = null

func _ready() -> void:
	# Find default skin
	for skin in owned_skins:
		if skin.is_default:
			_default_skin = skin
			break
	
	if _default_skin == null and owned_skins.size() > 0:
		_default_skin = owned_skins[0]
	
	if equipped_skin == null:
		equipped_skin = _default_skin


func has_skin(skin: SkinResource) -> bool:
	return owned_skins.has(skin)


func unlock_skin(skin: SkinResource) -> bool:
	if skin == null:
		return false
	if has_skin(skin):
		return false
	
	owned_skins.append(skin)
	skin_unlocked.emit(skin)
	SignalHub.skin_unlocked.emit(skin)
	return true


func equip_skin(skin: SkinResource) -> bool:
	if skin == null:
		return false
	if not has_skin(skin):
		return false
	
	if equipped_skin != null:
		skin_unequipped.emit(equipped_skin)
	
	equipped_skin = skin
	skin_equipped.emit(skin)
	SignalHub.skin_equipped.emit(skin)
	return true


func unequip_skin() -> void:
	if equipped_skin != null:
		var old := equipped_skin
		equipped_skin = _default_skin
		skin_unequipped.emit(old)
		SignalHub.skin_unequipped.emit(old)


func get_equipped_skin() -> SkinResource:
	return equipped_skin


func get_owned_skins() -> Array[SkinResource]:
	return owned_skins.duplicate()


func get_skins_by_rarity(rarity: int) -> Array[SkinResource]:
	var result: Array[SkinResource] = []
	for skin in owned_skins:
		if skin.rarity == rarity:
			result.append(skin)
	return result


func get_locked_skins(all_skins: Array[SkinResource]) -> Array[SkinResource]:
	var result: Array[SkinResource] = []
	for skin in all_skins:
		if not has_skin(skin):
			result.append(skin)
	return result


func can_afford(skin: SkinResource, gold: int) -> bool:
	return gold >= skin.unlock_cost


func debug_line() -> String:
	var equipped_name := equipped_skin.skin_name if equipped_skin != null else "none"
	return "locker: %d owned, equipped: %s" % [owned_skins.size(), equipped_name]