extends Node

## Central signal bus (autoload name: `SignalHub`).
##
## RULES — this file must stay boring:
## 1. Signals only. No state, no logic, no node references, no typing on gameplay
##    classes at parse time (only types that already exist).
## 2. Parameters use the narrowest *existing* type. Where the owning system does
##    not exist yet (weapons, food, elements...), the payload is typed as
##    `Resource`/`Variant` and gets tightened in the milestone that adds the class.
## 3. Emitting is always allowed; nothing here listens.
##
## Why a bus: the HUD, the map, audio and the tower must not hold references to
## each other. They react to facts instead. See docs/ARCHITECTURE.md.

# ---------------------------------------------------------------- match lifecycle
signal match_started(duration: float)
signal match_ended(winner_id: int)
signal match_phase_changed(phase: int, previous_phase: int)

# ------------------------------------------------------------------------ players
signal player_spawned(player: Node, spawn_position: Vector2)
signal player_died(player: Node, killer: Node)
signal player_damaged(player: Node, info: DamageInfo)
signal player_health_changed(player: Node, current: float, maximum: float)
signal player_state_changed(player: Node, from_state: StringName, to_state: StringName)

# ------------------------------------------------------------------ combat & items
signal weapon_changed(owner: Node, weapon: Resource)
signal item_collected(owner: Node, item: Resource, amount: int)
signal food_consumed(owner: Node, food: Resource)
signal hunger_changed(owner: Node, current: float, maximum: float)
signal rage_changed(owner: Node, current: float, maximum: float)
signal super_hunger_changed(owner: Node, active: bool)
signal merge_completed(owner: Node, result: Resource)

# ------------------------------------------------------------------------ elemental
signal elemental_status_applied(owner: Node, element_id: StringName, duration: float)
signal elemental_status_removed(owner: Node, element_id: StringName)
signal elemental_status_damaged(owner: Node, element_id: StringName, amount: float)

# ------------------------------------------------------------------ tower & floors
signal floor_changed(player: Node, from_floor_id: int, to_floor_id: int)
signal tower_floor_changed(floor_id: int)
signal floor_state_changed(floor_id: int, state: int)
signal floor_warning_started(floor_id: int, seconds_left: float)
signal floor_deletion_started(floor_id: int)
signal floor_deleted(floor_id: int)

# ------------------------------------------------------------------ floor travel
signal floor_travel_started(player: Node, target_floor_id: int, duration: float)
signal floor_travel_arrived(player: Node, floor_id: int)
signal floor_travel_cancelled(player: Node, reason: StringName)

# ------------------------------------------------------------------------ map / UI
signal map_opened()
signal map_closed()
## Generic HUD banner request ("⚠ INCOMING PLAYER", "FLOOR COLLAPSING"...).
## `kind` lets the HUD pick a style: &"info", &"warning", &"danger".
signal hud_notification(text: String, kind: StringName)

# ---------------------------------------------------------------------------- debug
signal debug_message(text: String)
