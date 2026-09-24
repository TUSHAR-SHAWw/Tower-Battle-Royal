extends Node2D

## Boot scene (M0).
##
## Its only job right now is to prove the toolchain: autoloads are alive, the
## input map matches InputActions, and the developer tools are wired. The match
## scene (M2) and the main menu (M17) replace it as the entry point.

@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	GameLog.info("Boot", "engine %s | autoloads: SignalHub, GameState, AudioManager, SceneRouter, DevTools" % Engine.get_version_info().get("string", "?"))
	_report_input_map()
	_register_debug_lines()
	_update_status_label()


func _report_input_map() -> void:
	var missing := InputActions.missing_actions()
	if missing.is_empty():
		GameLog.info("Boot", "input map OK (%d actions)" % InputActions.all().size())
	else:
		GameLog.err("Boot", "input map is missing %d action(s): %s" % [missing.size(), str(missing)])


func _register_debug_lines() -> void:
	DevTools.register_provider("match", _debug_match_line)
	DevTools.register_provider("route", _debug_route_line)
	DevTools.register_provider("state", _debug_player_state_line)
	DevTools.log_line("boot self-check done", &"result")


func _debug_match_line() -> String:
	return "%s %d/%d alive" % [GameState.phase_name(), GameState.players_alive, GameState.players_total]


func _debug_route_line() -> String:
	return String(SceneRouter.current_route) if SceneRouter.current_route != &"" else "<none>"


func _debug_player_state_line() -> String:
	var player := GameState.local_player
	if player == null:
		return "<no local player>"
	var machine := player.get_node_or_null(^"StateMachine") as StateMachine
	var health := player.get_node_or_null(^"HealthComponent")
	var parts: Array[String] = []
	if machine != null:
		parts.append(String(machine.current_state_name()))
	if health != null and health.has_method(&"debug_line"):
		parts.append(str(health.call(&"debug_line")))
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else str(player.name)


func _update_status_label() -> void:
	var engine_version: String = Engine.get_version_info().get("string", "?")
	_status_label.text = "\n".join(PackedStringArray([
		"TOWER  BATTLE  ROYAL",
		"foundation online — milestone M0",
		"",
		"Godot %s  ·  %s" % [engine_version, ProjectSettings.get_setting("application/config/name", "?")],
		"F3 debug overlay  ·  F10 cheat console",
	]))
