extends Node

## Developer-only helpers (autoload name: `DevTools`).
##
## Adds the debug overlay (F3) and the cheat console (F10) to every scene in
## debug builds, and does *nothing* in release builds — so shipping code cannot
## expose developer tools by accident. Gameplay systems register their own
## debug lines and cheat commands here instead of being known to this file.

var debug_overlay: DebugOverlay = null
var cheat_console: CheatConsole = null


func _ready() -> void:
	if not is_available():
		return
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	add_child(debug_overlay)

	cheat_console = CheatConsole.new()
	cheat_console.name = "CheatConsole"
	add_child(cheat_console)

	_register_default_commands()


## False in exported release builds (see docs/ARCHITECTURE.md, "Debug tools").
func is_available() -> bool:
	return OS.is_debug_build()


## Registers one line on the debug overlay. `provider` must return a String.
func register_provider(label: String, provider: Callable) -> void:
	if debug_overlay != null:
		debug_overlay.register_provider(label, provider)


func register_command(command_name: StringName, handler: Callable, help_text: String, usage: String = "") -> void:
	if cheat_console != null:
		cheat_console.register_command(command_name, handler, help_text, usage)


func log_line(text: String, kind: StringName = &"info") -> void:
	if cheat_console != null:
		cheat_console.log_line(text, kind)


## True while the console has keyboard focus; input polling should pause then.
func is_console_open() -> bool:
	return cheat_console != null and cheat_console.is_open()


# ------------------------------------------------------------------- default cmds

func _register_default_commands() -> void:
	register_command(&"help", _cmd_help, "List commands, or show one command's usage.", "help [command]")
	register_command(&"clear", _cmd_clear, "Clear the console history.")
	register_command(&"routes", _cmd_routes, "List registered and planned scene routes.")
	register_command(&"scene", _cmd_scene, "Switch to a registered scene route.", "scene <route>")
	register_command(&"overlay", _cmd_overlay, "Show or hide the debug overlay: on | off | toggle.", "overlay <on|off|toggle>")
	register_command(&"state", _cmd_state, "Print the current GameState summary.")
	register_command(&"quit", _cmd_quit, "Quit the game immediately.")
	register_command(&"boot", _cmd_boot, "Re-run the boot self-check.")

	# Player commands
	register_command(&"heal", _cmd_heal, "Heal the local player.", "heal <amount>")
	register_command(&"damage", _cmd_damage, "Damage the local player.", "damage <amount> [type]")
	register_command(&"gold", _cmd_gold, "Add/remove gold.", "gold <amount>")
	register_command(&"give_item", _cmd_give_item, "Give item to player.", "give_item <item_id> [count]")
	register_command(&"set_health", _cmd_set_health, "Set player health.", "set_health <current> [max]")
	register_command(&"set_hunger", _cmd_set_hunger, "Set player hunger (0-100).", "set_hunger <value>")
	register_command(&"set_rage", _cmd_set_rage, "Set player rage (0-100).", "set_rage <value>")
	register_command(&"speed_boost", _cmd_speed_boost, "Apply temporary speed boost.", "speed_boost <multiplier> [duration]")
	register_command(&"invincible", _cmd_invincible, "Toggle player invincibility.", "invincible [on|off|toggle]")

	# Tower / floor commands
	register_command(&"floor", _cmd_floor, "Get or set current tower floor.", "floor [floor_id]")
	register_command(&"travel", _cmd_travel, "Travel to a specific floor.", "travel <floor_id>")
	register_command(&"floor_state", _cmd_floor_state, "Set floor state.", "floor_state <ACTIVE|WARNING|COLLAPSING|DELETED>")
	register_command(&"spawn_floor", _cmd_spawn_floor, "Force spawn a floor.", "spawn_floor <floor_id>")
	register_command(&"delete_floor", _cmd_delete_floor, "Delete current floor.", "delete_floor")
	register_command(&"portal", _cmd_portal, "Spawn travel portal at player.", "portal [floor_id]")

	# Inventory / merge
	register_command(&"inv", _cmd_inv, "Show inventory contents.")
	register_command(&"merge", _cmd_merge, "Trigger merge with first available recipe.")
	register_command(&"craft", _cmd_craft, "Trigger craft with first recipe.")

	# Elemental
	register_command(&"apply_status", _cmd_apply_status, "Apply elemental status.", "apply_status <fire|ice|lightning|poison> [duration]")
	register_command(&"clear_status", _cmd_clear_status, "Clear all elemental statuses.")

	# Misc
	register_command(&"spawn_enemy", _cmd_spawn_enemy, "Spawn test enemy at player.", "spawn_enemy [type]")
	register_command(&"spawn_chest", _cmd_spawn_chest, "Spawn loot chest at player.")
	register_command(&"kill_all", _cmd_kill_all, "Kill all enemies on floor.")
	register_command(&"noclip", _cmd_noclip, "Toggle noclip mode.", "noclip [on|off|toggle]")
	register_command(&"timescale", _cmd_timescale, "Set engine time scale.", "timescale <value>")


func _cmd_help(args: PackedStringArray) -> String:
	if args.size() > 0:
		var name_key := StringName(args[0])
		if not cheat_console.has_command(name_key):
			return "unknown command: %s" % args[0]
		return cheat_console.command_usage(name_key)
	return cheat_console.command_summary()


func _cmd_clear(_args: PackedStringArray) -> String:
	cheat_console.clear_history()
	return ""


func _cmd_routes(_args: PackedStringArray) -> String:
	var lines: Array[String] = ["registered routes:"]
	for route: StringName in SceneRouter.list_routes():
		lines.append("  %s -> %s" % [route, SceneRouter.route_path(route)])
	lines.append("planned routes (scene not built yet):")
	for route: Variant in SceneRouter.PLANNED_ROUTES.keys():
		lines.append("  %s -> %s" % [route, SceneRouter.PLANNED_ROUTES[route]])
	return "\n".join(PackedStringArray(lines))


func _cmd_scene(args: PackedStringArray) -> String:
	if args.is_empty():
		return "usage: scene <route|path>"
	var target := StringName(args[0])
	if not SceneRouter.has_route(target):
		return "no such route: %s" % args[0]
	var error := SceneRouter.goto(target)
	return "goto %s -> %s" % [target, error_string(error)]


func _cmd_overlay(args: PackedStringArray) -> String:
	if debug_overlay == null:
		return "overlay unavailable"
	var mode := args[0].to_lower() if args.size() > 0 else "toggle"
	match mode:
		"on":
			debug_overlay.visible = true
		"off":
			debug_overlay.visible = false
		"toggle":
			debug_overlay.visible = not debug_overlay.visible
		_:
			return "usage: overlay <on|off|toggle>"
	return "overlay %s" % ("visible" if debug_overlay.visible else "hidden")


func _cmd_state(_args: PackedStringArray) -> String:
	return "phase=%s elapsed=%.1f/%.1f alive=%d/%d floors=%d" % [
		GameState.phase_name(),
		GameState.match_elapsed,
		GameState.match_duration,
		GameState.players_alive,
		GameState.players_total,
		GameState.tower_floor_count,
	]


func _cmd_quit(_args: PackedStringArray) -> String:
	get_tree().quit()
	return "quitting"


func _cmd_boot(_args: PackedStringArray) -> String:
	InputActions.missing_actions()
	return "input map: %s" % ("OK" if InputActions.missing_actions().is_empty() else "MISSING ACTIONS — see log")


# ===================================================================== PLAYER COMMANDS

func _get_player() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var player_instance: Node = tree.current_scene.get_node_or_null("PlayerInstance")
	var player: Node = tree.current_scene.get_node_or_null("Player")
	return player_instance if player_instance != null else player


func _cmd_heal(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var amount := args[0].to_float() if args.size() > 0 else 100.0
	var health := player.get_node_or_null("HealthComponent")
	if health == null:
		return "no HealthComponent"
	health.heal(amount)
	return "healed %.1f" % amount


func _cmd_damage(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var amount := args[0].to_float() if args.size() > 0 else 10.0
	var dtype := DamageTypes.BULLET
	if args.size() > 1 and DamageTypes.is_valid(StringName(args[1])):
		dtype = StringName(args[1])
	var info := DamageInfo.create(amount, dtype, player, player)
	var health := player.get_node_or_null("HealthComponent")
	if health == null:
		return "no HealthComponent"
	var applied: float = health.apply_damage(info)
	return "applied %.1f damage (type=%s)" % [applied, dtype]


func _cmd_gold(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var amount := args[0].to_int() if args.size() > 0 else 100
	var inv := player.get_node_or_null("InventoryComponent")
	if inv == null:
		return "no InventoryComponent"
	if amount >= 0:
		inv.add_item(load("res://resources/items/gold.tres") as ItemResource, amount)
	else:
		inv.remove_item(&"gold", -amount)
	return "gold %+d" % amount


func _cmd_give_item(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	if args.is_empty():
		return "usage: give_item <item_id> [count]"
	var item_id := StringName(args[0])
	var count := args[1].to_int() if args.size() > 1 else 1
	var inv := player.get_node_or_null("InventoryComponent")
	if inv == null:
		return "no InventoryComponent"
	# Try to load item resource
	var path := "res://resources/items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return "item not found: %s" % item_id
	var item := load(path) as ItemResource
	inv.add_item(item, count)
	return "gave %d × %s" % [count, item_id]


func _cmd_set_health(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var current := args[0].to_float() if args.size() > 0 else 100.0
	var max_hp := args[1].to_float() if args.size() > 1 else current
	var health := player.get_node_or_null("HealthComponent")
	if health == null:
		return "no HealthComponent"
	health.max_health = max_hp
	health.current_health = current
	return "health set to %.1f/%.1f" % [current, max_hp]


func _cmd_set_hunger(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var value := args[0].to_float() if args.size() > 0 else 100.0
	var hunger := player.get_node_or_null("HungerComponent")
	if hunger == null:
		return "no HungerComponent"
	hunger.current_hunger = clamp(value, 0.0, hunger.max_hunger)
	return "hunger set to %.1f" % hunger.current_hunger


func _cmd_set_rage(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var value := args[0].to_float() if args.size() > 0 else 100.0
	var rage := player.get_node_or_null("RageComponent")
	if rage == null:
		return "no RageComponent"
	rage.current_rage = clamp(value, 0.0, rage.max_rage)
	return "rage set to %.1f" % rage.current_rage


func _cmd_speed_boost(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var mult := args[0].to_float() if args.size() > 0 else 2.0
	var dur := args[1].to_float() if args.size() > 1 else 10.0
	var movement := player.get_node_or_null("MovementComponent")
	if movement == null:
		return "no MovementComponent"
	movement.apply_speed_boost(mult, dur)
	return "speed boost %.1fx for %.1fs" % [mult, dur]


func _cmd_invincible(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var health := player.get_node_or_null("HealthComponent")
	if health == null:
		return "no HealthComponent"
	var mode := args[0].to_lower() if args.size() > 0 else "toggle"
	match mode:
		"on":
			health.invincible = true
		"off":
			health.invincible = false
		"toggle":
			health.invincible = not health.invincible
		_:
			return "usage: invincible <on|off|toggle>"
	return "invincible %s" % ("on" if health.invincible else "off")


# ===================================================================== TOWER / FLOOR COMMANDS

func _get_tower() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("TowerController")


func _get_current_floor() -> Node:
	var tower := _get_tower()
	if tower == null:
		return null
	return tower.get_current_floor()


func _cmd_floor(args: PackedStringArray) -> String:
	var tower := _get_tower()
	if tower == null:
		return "no TowerController"
	if args.is_empty():
		return "current floor: %d" % tower.get_current_floor_id()
	var floor_id := args[0].to_int()
	if floor_id < 1:
		return "floor_id must be >= 1"
	# This would require tower to have a goto_floor method
	return "floor %d (manual travel not implemented in tower controller)" % floor_id


func _cmd_travel(args: PackedStringArray) -> String:
	var tower := _get_tower()
	if tower == null:
		return "no TowerController"
	if args.is_empty():
		return "usage: travel <floor_id>"
	var target := args[0].to_int()
	if tower.has_method("start_travel"):
		tower.start_travel(target)
		return "traveling to floor %d" % target
	return "tower doesn't support travel"


func _cmd_floor_state(args: PackedStringArray) -> String:
	var floor := _get_current_floor()
	if floor == null:
		return "no current floor"
	if not floor.has_method("set_state"):
		return "floor doesn't support state change"
	if args.is_empty():
		return "usage: floor_state <ACTIVE|WARNING|COLLAPSING|DELETED>"
	var state_str := args[0].to_upper()
	var state_map := {
		"ACTIVE": 0,
		"WARNING": 1,
		"COLLAPSING": 2,
		"DELETED": 3
	}
	if not state_map.has(state_str):
		return "invalid state: %s (use ACTIVE, WARNING, COLLAPSING, DELETED)" % state_str
	floor.set_state(state_map[state_str])
	return "floor state set to %s" % state_str


func _cmd_spawn_floor(args: PackedStringArray) -> String:
	var tower := _get_tower()
	if tower == null:
		return "no TowerController"
	if args.is_empty():
		return "usage: spawn_floor <floor_id>"
	var floor_id := args[0].to_int()
	if tower.tower_data.size() < floor_id:
		return "floor %d doesn't exist in tower data" % floor_id
	# TowerController would need a spawn_floor method
	return "spawn floor %d (manual spawn not implemented in tower controller)" % floor_id


func _cmd_delete_floor(args: PackedStringArray) -> String:
	var floor := _get_current_floor()
	if floor == null:
		return "no current floor"
	if floor.has_method("start_deletion"):
		floor.start_deletion()
		return "floor deletion started"
	return "floor doesn't support deletion"


func _cmd_portal(args: PackedStringArray) -> String:
	var floor := _get_current_floor()
	if floor == null:
		return "no current floor"
	var tower := _get_tower()
	var current_floor_id: int = 1
	if tower != null and tower.has_method("get_current_floor_id"):
		current_floor_id = tower.get_current_floor_id()
	var target_floor: int = args[0].to_int() if args.size() > 0 else (current_floor_id + 1)
	# Would need to instance TravelPortal at player position
	return "portal to floor %d (not fully implemented)" % target_floor


# ===================================================================== INVENTORY / MERGE COMMANDS

func _cmd_inv(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var inv := player.get_node_or_null("InventoryComponent")
	if inv == null:
		return "no InventoryComponent"
	return inv.debug_line()


func _cmd_merge(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var merge := player.get_node_or_null("MergeComponent")
	if merge == null:
		return "no MergeComponent"
	var inv := player.get_node_or_null("InventoryComponent")
	if inv == null:
		return "no InventoryComponent"
	if merge.available_recipes.size() == 0:
		return "no recipes available"
	if merge.start_merge(merge.available_recipes[0], inv):
		return "merge started"
	return "cannot merge"


func _cmd_craft(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var hub := player.get_node_or_null("CentralHub") or player.get_node_or_null("HubController")
	if hub == null:
		return "no CraftingStation"
	return "craft (not fully implemented)"


# ===================================================================== ELEMENTAL COMMANDS

func _cmd_apply_status(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	if args.is_empty():
		return "usage: apply_status <fire|ice|lightning|poison> [duration]"
	var element := args[0].to_lower()
	if not ["fire", "ice", "lightning", "poison"].has(element):
		return "invalid element: %s (use fire, ice, lightning, poison)" % element
	var dur := args[1].to_float() if args.size() > 1 else 5.0
	var elemental := player.get_node_or_null("ElementalComponent")
	if elemental == null:
		return "no ElementalComponent"
	elemental.apply_status(StringName(element), dur)
	return "applied %s for %.1fs" % [element, dur]


func _cmd_clear_status(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var elemental := player.get_node_or_null("ElementalComponent")
	if elemental == null:
		return "no ElementalComponent"
	elemental.clear_all_status()
	return "cleared all statuses"


# ===================================================================== MISC COMMANDS

func _cmd_spawn_enemy(args: PackedStringArray) -> String:
	return "spawn_enemy (not implemented)"


func _cmd_spawn_chest(args: PackedStringArray) -> String:
	var floor := _get_current_floor()
	if floor == null:
		return "no current floor"
	# Would instance LootChest
	return "spawn_chest (not fully implemented)"


func _cmd_kill_all(args: PackedStringArray) -> String:
	return "kill_all (not implemented)"


func _cmd_noclip(args: PackedStringArray) -> String:
	var player := _get_player()
	if player == null:
		return "no player found"
	var mode := args[0].to_lower() if args.size() > 0 else "toggle"
	# Would modify collision layers
	return "noclip %s (not implemented)" % mode


func _cmd_timescale(args: PackedStringArray) -> String:
	if args.is_empty():
		return "usage: timescale <value> (1.0 = normal, 0.5 = half speed, 2.0 = double)"
	var scale := args[0].to_float()
	Engine.time_scale = clamp(scale, 0.01, 10.0)
	return "time scale set to %.2f" % Engine.time_scale
