extends CanvasLayer
class_name HUD

## Main gameplay HUD — visible now with real Control nodes, not only code-drawn.
## Listens to SignalHub and updates panels, health bars, ammo, gold, wave/floor.

@onready var health_fill: ProgressBar = $BackgroundCard/TopLeft/HealthPanel/HealthRow/HealthFill
@onready var ammo_text: Label = $BackgroundCard/BottomLeft/AmmoPanel/AmmoText
@onready var weapon_text: Label = $BackgroundCard/BottomLeft/WeaponName
@onready var gold_text: Label = $BackgroundCard/TopRight/GoldPanel/GoldText
@onready var floor_text: Label = $BackgroundCard/TopRight/FloorPanel/FloorText
@onready var wave_text: Label = $BackgroundCard/TopLeft/WavePanel/WaveText
@onready var notification: Label = $BackgroundCard/NotificationLabel

func _ready() -> void:
	# Make visible immediately — no hidden wait for signals.
	if health_fill != null:
		health_fill.value = 100
		health_fill.modulate = Color(0.2, 0.8, 0.2, 1)
	if ammo_text != null:
		ammo_text.text = "30 / 120"
	if wave_text != null:
		wave_text.text = "WAVE 1"
	if floor_text != null:
		floor_text.text = "FLOOR 1"
	if gold_text != null:
		gold_text.text = "4500"

	# Connect signals
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

func _on_health_changed(n: Node, current: float, maximum: float) -> void:
	if health_fill == null: return
	health_fill.value = (current / maximum) * 100.0 if maximum > 0 else 0.0
	health_fill.modulate = Color(0.2, 0.8, 0.2, 1) if current / maximum > 0.6 else (Color(1.0, 0.75, 0.1, 1) if current / maximum > 0.3 else Color(0.85, 0.15, 0.15, 1))

func _on_ammo_changed(current_mag: int, reserve: int, weapon_id: StringName) -> void:
	if ammo_text != null:
		ammo_text.text = "%d / %d" % [current_mag, reserve]

func _on_weapon_changed(_owner: Node, weapon: Resource) -> void:
	if weapon_text != null and weapon != null:
		weapon_text.text = weapon.weapon_name

func _on_gold_changed(current: int, delta: int) -> void:
	if gold_text != null:
		gold_text.text = "%d" % current

func _on_xp_changed(current: int, delta: int) -> void:
	pass

func _on_level_up(new_level: int) -> void:
	if notification != null:
		notification.text = "LEVEL %d" % new_level
		notification.visible = true
		notification.modulate = Color(1, 0.95, 0.1, 1)

func _on_wave_started(wave_id: int, floor_id: int) -> void:
	if wave_text != null:
		wave_text.text = "WAVE %d" % wave_id
	if notification != null:
		notification.text = "WAVE %d — FLOOR %d" % [wave_id, floor_id]
		notification.visible = true
		notification.modulate = Color(0.2, 0.8, 1.0, 1.0)

func _on_floor_changed(new_floor: int) -> void:
	if floor_text != null:
		floor_text.text = "FLOOR %d" % new_floor

func _on_hunger_changed(_owner: Node, current: float, maximum: float) -> void:
	pass

func _on_rage_changed(_owner: Node, current: float, maximum: float) -> void:
	pass

func _on_notification(text: String) -> void:
	if notification != null:
		notification.text = text
		notification.visible = true
		notification.modulate = Color(1, 0.95, 0.1, 1)
