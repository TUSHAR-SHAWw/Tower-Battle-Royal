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
signal weapon_fired(weapon_id: StringName, position: Vector2, direction: Vector2)
signal weapon_reload_started(weapon_id: StringName)
signal weapon_reload_finished(weapon_id: StringName)
signal weapon_ammo_changed(current: int, reserve: int, weapon_id: StringName)
signal melee_attack_started(weapon_id: StringName, combo_index: int)
signal melee_attack_hit(weapon_id: StringName, target: Node, info: DamageInfo)
signal melee_hitbox_activated()
signal melee_hitbox_deactivated()
signal melee_combo_window_open()
signal melee_combo_window_close()
signal item_used(item_id: StringName)
signal item_collected(owner: Node, item: Resource, amount: int)
signal item_bought(item: ItemResource, price: int, remaining_stock: int)
signal item_sold(item: ItemResource, price: int)
signal item_crafted(recipe: MergeRecipe, success: bool, output: ItemResource)
signal item_upgraded(item: ItemResource, target_tier: int, success: bool)
signal food_consumed(owner: Node, food: Resource)
signal hunger_changed(owner: Node, current: float, maximum: float)
signal hunger_threshold_crossed(level: int)
signal rage_changed(owner: Node, current: float, maximum: float)
signal rage_mode_changed(active: bool)
signal super_hunger_changed(owner: Node, active: bool)
signal elemental_status_applied(owner: Node, element_id: StringName, duration: float)
signal elemental_status_removed(owner: Node, element_id: StringName)
signal elemental_status_damaged(owner: Node, element_id: StringName, amount: float)
signal merge_started(recipe: MergeRecipe)
signal merge_completed(recipe: MergeRecipe, success: bool, output: ItemResource)
signal merge_failed(recipe: MergeRecipe, reason: StringName)
signal skin_equipped(skin: SkinResource)
signal skin_unequipped(skin: SkinResource)
signal skin_unlocked(skin: SkinResource)

# ------------------------------------------------------------- enemies & bosses
signal enemy_spawned(enemy: Node)
signal enemy_spawned_on_floor(enemy: Node, floor_id: int)
signal enemy_died(enemy: Node, killer: Node)
signal enemy_attacked(attacker: Node, target: Node)
signal wave_started(wave: int, floor_id: int)
signal wave_completed(wave: int, floor_id: int)
signal all_waves_completed(floor_id: int)
signal boss_spawned(boss: Node, floor_id: int)
signal boss_died(boss: Node, floor_id: int)
signal boss_phase_changed(boss: Node, phase: int)
signal boss_phase_changed_on_floor(phase: int, floor_id: int)
signal boss_died_on_floor(killer: Node, floor_id: int)

# ------------------------------------------------------------------ economy
signal gold_changed(current: int, delta: int)
signal xp_changed(current: int, delta: int)
signal level_up(new_level: int)
signal battle_pass_xp_changed(current: int, delta: int)
signal battle_pass_tier_unlocked(tier: int, is_premium: bool)
signal daily_reward_claimed(day: int, rewards: Array[Dictionary])
signal daily_streak_broken(old_streak: int)
signal battle_pass_xp_added(amount: int)
signal battle_pass_premium_purchased()

# ---------------------------------------------------------------------- hub
signal hub_entered(player: Node)
signal hub_exited(player: Node)
signal hub_service_used(service_id: StringName, player: Node)

# ------------------------------------------------------------------ tower & floors
signal floor_changed(player: Node, from_floor_id: int, to_floor_id: int)
signal tower_floor_changed(floor_id: int)
signal floor_state_changed(floor_id: int, state: int)
signal floor_warning_started(floor_id: int, seconds_left: float)
signal floor_deletion_started(floor_id: int)
signal floor_deleted(floor_id: int)

# ----------------------------------------------------------------- central platform
signal central_platform_started()
signal central_platform_floor_reached(floor_id: int)
signal descent_accelerated()
signal descent_stopped()

# ------------------------------------------------------------- network (M16/M20)
signal network_client_connected(client_id: int)
signal network_client_disconnected(client_id: int)
signal network_player_spawned(net_id: int, player_name: String)
signal network_player_despawned(net_id: int)
signal network_snapshot_received(tick: int)
signal player_spawned_in_match(msg: Dictionary)

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
