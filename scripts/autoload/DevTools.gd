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
