extends CharacterBody2D
class_name Player

## Composed player actor.
##
## Structure:
##   Player (CharacterBody2D)
##   ├── CollisionShape2D
##   ├── Visual (Node2D)          ← placeholder art, code-drawn
##   ├── Hurtbox (Area2D)         ← receives damage
##   ├── Camera2D
##   ├── InputSource (InputDriver)
##   ├── MovementComponent
##   ├── HealthComponent
##   ├── CameraComponent
##   ├── StateMachine (states as children)
##   ├── GunComponent
##   ├── MeleeComponent
##   └── PlayerConfig (Resource)

signal died

@export var config: PlayerConfig
@export var input_source: InputSource
@export var movement: MovementComponent
@export var health: HealthComponent
@export var camera_component: CameraComponent
@export var state_machine: StateMachine
@export var visual: Node2D
@export var hurtbox: Area2D
@export var gun: GunComponent
@export var melee: MeleeComponent

var _aim_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_configure_from_config()
	_wire_components()
	_wire_signals()
	state_machine.setup(self)
	state_machine.start()

	# Register self as local player for debug/cheat tools.
	GameState.local_player = self

	# Cheat commands for this player.
	DevTools.register_command(&"player_damage", _cmd_damage, "Damage the player.", "player_damage <amount> [type]")
	DevTools.register_command(&"player_heal", _cmd_heal, "Heal the player.", "player_heal <amount>")
	DevTools.register_command(&"player_kill", _cmd_kill, "Kill the player.")
	DevTools.register_command(&"player_revive", _cmd_revive, "Revive the player at full health.")
	DevTools.register_command(&"player_state", _cmd_force_state, "Force player state machine to a state.", "player_state <state_name>")

	DevTools.register_provider("player", _debug_player_line)


func _configure_from_config() -> void:
	if config == null:
		# Load default config resource if not assigned in the scene.
		config = load("res://resources/player/player_default.tres") as PlayerConfig
	if config == null:
		push_error("Player: failed to load PlayerConfig.")
		return

	# Collision shape radius.
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = config.radius
	add_child(shape)
	shape.owner = self

	# Physics layers.
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.player_obstacles()


func _wire_components() -> void:
	# MovementComponent needs the body reference.
	if movement != null:
		movement.body = self

	# CameraComponent needs the camera and config.
	if camera_component != null:
		camera_component.camera = get_node_or_null("Camera2D") as Camera2D
		camera_component.config = config

	# VisualComponent needs config for drawing.
	if visual != null and config != null:
		visual.config = config

	# HealthComponent gets max health from config.
	if health != null and config != null:
		health.max_health = config.max_health
		health.current_health = config.max_health

	# GunComponent gets weapon from config (if assigned).
	if gun != null:
		gun.shot_fired.connect(_on_shot_fired)
		gun.reload_started.connect(_on_reload_started)
		gun.reload_finished.connect(_on_reload_finished)
		gun.ammo_changed.connect(_on_ammo_changed)
		gun.fire_blocked.connect(_on_fire_blocked)

	# MeleeComponent
	if melee != null:
		melee.attack_started.connect(_on_melee_attack_started)
		melee.hitbox_activated.connect(_on_melee_hitbox_activated)
		melee.hitbox_deactivated.connect(_on_melee_hitbox_deactivated)
		melee.attack_hit.connect(_on_melee_attack_hit)
		melee.combo_window_open.connect(_on_melee_combo_window_open)
		melee.combo_window_close.connect(_on_melee_combo_window_close)
		melee.attack_blocked.connect(_on_melee_attack_blocked)


func _wire_signals() -> void:
	if health != null:
		health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	# Poll input and update aim direction before states run.
	if input_source != null and input_source.is_enabled():
		var intent := input_source.poll(self)
		_aim_direction = intent.aim_dir
		
		# Handle fire input
		if intent.fire_held and gun != null:
			gun.try_fire(_aim_direction, global_position)
		
		# Handle melee input
		if intent.melee_pressed and melee != null:
			melee.try_attack(_aim_direction)
	
	# Camera follows in physics frame for stability.
	if camera_component != null:
		camera_component.update(delta)


func _process(delta: float) -> void:
	# Visual flash on damage, etc. could go here.
	pass


## Returns the current aim direction (used by camera lead, weapons later).
func get_aim_direction() -> Vector2:
	return _aim_direction


## Public API for external damage sources.
func take_damage(info: DamageInfo) -> float:
	if health == null:
		return 0.0
	return health.apply_damage(info)


## Revive at current position (used by cheat / respawn).
func revive() -> void:
	if health != null:
		health.revive()
	if state_machine != null and state_machine.has_state(&"idle"):
		state_machine.transition_to(&"idle")


# ------------------------------------------------------------------------ signals

func _on_died(info: DamageInfo) -> void:
	died.emit()
	SignalHub.player_health_changed.emit(self, 0.0, health.max_health if health != null else 100.0)


# ------------------------------------------------------------------------ gun signals

func _on_shot_fired(position: Vector2, direction: Vector2, weapon_id: StringName) -> void:
	SignalHub.weapon_fired.emit(weapon_id, position, direction)


func _on_reload_started() -> void:
	SignalHub.weapon_reload_started.emit(gun.weapon.weapon_id if gun.weapon != null else &"unknown")


func _on_reload_finished() -> void:
	SignalHub.weapon_reload_finished.emit(gun.weapon.weapon_id if gun.weapon != null else &"unknown")


func _on_ammo_changed(current: int, reserve: int) -> void:
	SignalHub.weapon_ammo_changed.emit(current, reserve, gun.weapon.weapon_id if gun.weapon != null else &"unknown")


func _on_fire_blocked(reason: StringName) -> void:
	# Could play a click sound or show UI feedback
	pass


# ------------------------------------------------------------------------ melee signals

func _on_melee_attack_started(combo_index: int, total_frames: int) -> void:
	SignalHub.melee_attack_started.emit(melee.weapon.weapon_id if melee.weapon != null else &"unknown", combo_index)


func _on_melee_hitbox_activated() -> void:
	SignalHub.melee_hitbox_activated.emit()


func _on_melee_hitbox_deactivated() -> void:
	SignalHub.melee_hitbox_deactivated.emit()


func _on_melee_attack_hit(target: Node, info: DamageInfo) -> void:
	SignalHub.melee_attack_hit.emit(melee.weapon.weapon_id if melee.weapon != null else &"unknown", target, info)


func _on_melee_combo_window_open() -> void:
	SignalHub.melee_combo_window_open.emit()


func _on_melee_combo_window_close() -> void:
	SignalHub.melee_combo_window_close.emit()


func _on_melee_attack_blocked(reason: StringName) -> void:
	# Could play a blocked sound or show UI feedback
	pass


# ------------------------------------------------------------------------ debug / cheats

func _debug_player_line() -> String:
	var parts: Array[String] = []
	if state_machine != null:
		parts.append(String(state_machine.current_state_name()))
	if movement != null:
		parts.append(movement.debug_line())
	if health != null:
		parts.append(health.debug_line())
	if camera_component != null:
		parts.append(camera_component.debug_line())
	if gun != null:
		parts.append("gun: %s (%d/%d)%s" % [gun.weapon.weapon_name if gun.weapon != null else "none", gun.get_current_mag(), gun.get_reserve_ammo(), " RELOADING" if gun.is_reloading() else ""])
	if melee != null:
		parts.append("melee: %s (c%d %s)" % [melee.weapon.weapon_name if melee.weapon != null else "none", melee.get_combo_index(), melee.get_state()])
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else name


func _cmd_damage(args: PackedStringArray) -> String:
	if args.is_empty():
		return "usage: player_damage <amount> [bullet|melee|...]"
	var amount := args[0].to_float()
	var dtype := DamageTypes.BULLET
	if args.size() > 1 and DamageTypes.is_valid(StringName(args[1])):
		dtype = StringName(args[1])
	var info := DamageInfo.create(amount, dtype, self, self)
	var applied := take_damage(info)
	return "applied %.1f damage (type=%s)" % [applied, dtype]


func _cmd_heal(args: PackedStringArray) -> String:
	if args.is_empty():
		return "usage: player_heal <amount>"
	var amount := args[0].to_float()
	if health == null:
		return "no health component"
	var restored := health.heal(amount)
	return "healed %.1f" % restored


func _cmd_kill(_args: PackedStringArray) -> String:
	if health == null:
		return "no health component"
	health.kill(self)
	return "killed"


func _cmd_revive(_args: PackedStringArray) -> String:
	revive()
	return "revived"


func _cmd_force_state(args: PackedStringArray) -> String:
	if args.is_empty():
		return "usage: player_state <idle|move|sprint|dead>"
	if state_machine == null:
		return "no state machine"
	var ok := state_machine.transition_to(StringName(args[0]))
	return "transition %s" % ("ok" if ok else "failed")