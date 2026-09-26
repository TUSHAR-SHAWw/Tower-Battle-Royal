class_name InputActions
extends RefCounted

## Action-name constants. These mirror the `[input]` section of project.godot —
## project settings cannot reference constants, so the literals exist in both
## places. tests/foundation/input_map_test.gd asserts they never drift apart,
## which also proves project.godot parsed correctly.

# Movement (keyboard layout independent: physical keycodes).
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const SPRINT := &"sprint"

# Twin-stick aiming (gamepad right stick / touch stick later).
const AIM_UP := &"aim_up"
const AIM_DOWN := &"aim_down"
const AIM_LEFT := &"aim_left"
const AIM_RIGHT := &"aim_right"

# Combat.
const FIRE := &"fire"
const MELEE_ATTACK := &"melee_attack"
const RELOAD := &"reload"
const INTERACT := &"interact"
## Uses the selected hotbar slot (eat food, spend a merge item, ...).
const USE_SELECTED := &"use_selected"
const MERGE := &"merge"

# UI / systems.
const TOGGLE_MAP := &"toggle_map"

# Hotbar slots, index 0 == slot 1.
const SLOT_ACTIONS: Array[StringName] = [&"slot_1", &"slot_2", &"slot_3", &"slot_4", &"slot_5", &"slot_6"]

# Developer tools.
const DEBUG_TOGGLE_OVERLAY := &"debug_toggle_overlay"
const DEBUG_TOGGLE_CONSOLE := &"debug_toggle_console"


## Every gameplay action this project expects to exist in the InputMap.
static func all() -> Array[StringName]:
	var actions: Array[StringName] = [
		MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, SPRINT,
		AIM_UP, AIM_DOWN, AIM_LEFT, AIM_RIGHT,
		FIRE, MELEE_ATTACK, RELOAD, INTERACT, USE_SELECTED, MERGE,
		TOGGLE_MAP,
		DEBUG_TOGGLE_OVERLAY, DEBUG_TOGGLE_CONSOLE,
	]
	actions.append_array(SLOT_ACTIONS)
	return actions


## Validates the InputMap and returns the names that are missing (empty = healthy).
static func missing_actions() -> Array[StringName]:
	var missing: Array[StringName] = []
	for action: StringName in all():
		if not InputMap.has_action(action):
			missing.append(action)
	return missing
