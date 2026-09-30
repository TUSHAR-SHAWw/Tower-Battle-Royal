class_name HUD
extends CanvasLayer

## Main gameplay HUD — purely presentational, listens to SignalHub.
## All UI updates come from signals; no gameplay logic here.

@onready var health_bg: PanelContainer = $HealthBar/HealthBG
@onready var health_fill: PanelContainer = $HealthBar/HealthBG/HealthFill
@onready var health_text: Label = $HealthBar/HealthText
@onready var hunger_bg: PanelContainer = $HungerBar/HungerBG
@onready var hunger_fill: PanelContainer = $HungerBar/HungerBG/HungerFill
@onready var hunger_text: Label = $HungerBar/HungerText
@onready var rage_bg: PanelContainer = $RageBar/RageBG
@onready var rage_fill: PanelContainer = $RageBar/RageBG/RageFill
@onready var rage_text: Label = $RageBar/RageText
@onready var ammo_text: Label = $AmmoContainer/AmmoText
@onready var weapon_name: Label = $AmmoContainer/WeaponName
@onready var gold_text: Label = $GoldContainer/GoldText
@onready var xp_text: Label = $XPContainer/XPText
@onready var wave_text: Label = $WaveText
@onready var floor_text: Label = $FloorText
@onready var notification: Label = $Notification

var _notification_timer: float = 0.0


func _ready() -> void:
	SignalHub.player_health_changed.connect(_on_health_changed)
	SignalHub.hunger_changed.connect(_on_hunger_changed)
	SignalHub.rage_changed.connect(_on_rage_changed)
	SignalHub.weapon_ammo_changed.connect(_on_ammo_changed)
	SignalHub.weapon_changed.connect(_on_weapon_changed)
	SignalHub.gold_changed.connect(_on_gold_changed)
	SignalHub.xp_changed.connect(_on_xp_changed)
	SignalHub.level_up.connect(_on_level_up)
	SignalHub.wave_started.connect(_on_wave_started)
	SignalHub.tower_floor_changed.connect(_on_floor_changed)
	SignalHub.hud_notification.connect(_on_notification)


func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			notification.visible = false
			notification.modulate = Color(1, 1, 1, 0)


func _on_health_changed(_player: Node, current: float, maximum: float) -> void:
	var ratio := current / maximum if maximum > 0 else 0.0
	health_fill.anchor_right = ratio
	health_text.text = "%.0f / %.0f" % [current, maximum]
	var color := Color(0.8, 0.2, 0.2, 1)
	if ratio > 0.6:
		color = Color(0.2, 0.8, 0.2, 1)
	elif ratio > 0.3:
		color = Color(1, 0.8, 0.1, 1)
	health_fill.modulate = color


func _on_hunger_changed(_owner: Node, current: float, maximum: float) -> void:
	var ratio := current / maximum if maximum > 0 else 0.0
	hunger_fill.anchor_right = ratio
	hunger_text.text = "HUNGER: %.0f%%" % (ratio * 100)
	var color := Color(1, 0.6, 0.1, 1)
	if ratio > 0.6:
		color = Color(0.2, 0.8, 0.2, 1)
	elif ratio < 0.25:
		color = Color(1, 0.2, 0.2, 1)
	hunger_fill.modulate = color


func _on_rage_changed(_owner: Node, current: float, maximum: float) -> void:
	var ratio := current / maximum if maximum > 0 else 0.0
	rage_fill.anchor_right = ratio
	rage_text.text = "RAGE: %.0f%%" % (ratio * 100)
	rage_fill.modulate = Color(0.8, 0.2, 0.8, 1) if ratio > 0 else Color(0.3, 0.05, 0.2, 1)


func _on_ammo_changed(current: int, reserve: int, weapon_id: StringName) -> void:
	ammo_text.text = "%d / %d" % [current, reserve]


func _on_weapon_changed(_owner: Node, weapon: Resource) -> void:
	if weapon != null:
		var weapon_name_str: String = weapon.weapon_name if weapon.weapon_name != "" else weapon.resource_path
		weapon_name.text = weapon_name_str
	else:
		weapon_name.text = "NONE"


func _on_gold_changed(current: int, _delta: int) -> void:
	gold_text.text = "%d" % current


func _on_xp_changed(current: int, _delta: int) -> void:
	xp_text.text = "Lv.1  %d XP" % current


func _on_level_up(new_level: int) -> void:
	xp_text.text = "Lv.%d  0 XP" % new_level
	_show_notification("LEVEL UP! → %d" % new_level, &"info")


func _on_wave_started(wave: int, _floor: int) -> void:
	wave_text.text = "Wave: %d" % wave
	_show_notification("WAVE %d STARTED" % wave, &"warning")


func _on_floor_changed(floor_id: int) -> void:
	floor_text.text = "Floor: %d" % floor_id
	_show_notification("ENTERED FLOOR %d" % floor_id, &"info")


func _on_notification(text: String, _kind: StringName) -> void:
	_show_notification(text, &"info")


func _show_notification(text: String, _kind: StringName) -> void:
	notification.text = text
	notification.visible = true
	notification.modulate = Color(1, 1, 1, 1)
	_notification_timer = 3.0