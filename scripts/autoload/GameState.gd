extends Node

## Global match state (autoload name: `GameState`).
##
## Scope: match-level facts only — phase, clock, player counts, tower size.
## It holds no gameplay logic and no references to gameplay nodes (see
## docs/ARCHITECTURE.md). Systems that need to know "is the match running?"
## read this; systems that change it call the methods below, which emit signals.

enum MatchPhase {
	IDLE,      ## Nothing running (menus).
	LOBBY,     ## Waiting for players.
	LOADING,   ## Building the tower / loading the floor.
	PREPARING, ## Spawn phase, no combat yet.
	RUNNING,   ## Live match.
	ENDED,     ## Results.
}

## PROTOTYPE DEFAULT — not final balance. Real values come from MatchConfig (M2).
const DEFAULT_MATCH_DURATION := 600.0

var phase: MatchPhase = MatchPhase.IDLE
var match_duration: float = 0.0
var match_elapsed: float = 0.0
var players_total: int = 0
var players_alive: int = 0
var tower_floor_count: int = 0

## Set by the match scene in M2 so UI can ask "where am I?".
var local_player: Node = null


func _process(delta: float) -> void:
	# Cheap early-out: no clock work outside a live match.
	if phase != MatchPhase.RUNNING:
		return
	match_elapsed = minf(match_elapsed + delta, match_duration)


## Starts a match and puts the state into RUNNING.
func start_match(duration: float = DEFAULT_MATCH_DURATION, player_count: int = 1) -> void:
	match_duration = maxf(duration, 0.0)
	match_elapsed = 0.0
	players_total = player_count
	players_alive = player_count
	set_phase(MatchPhase.RUNNING)
	SignalHub.match_started.emit(match_duration)
	SignalHub.debug_message.emit("match started (%.0fs, %d players)" % [match_duration, player_count])


func end_match(winner_id: int = -1) -> void:
	set_phase(MatchPhase.ENDED)
	SignalHub.match_ended.emit(winner_id)
	SignalHub.debug_message.emit("match ended (winner_id=%d)" % winner_id)


func set_phase(next_phase: MatchPhase) -> void:
	if next_phase == phase:
		return
	var previous := phase
	phase = next_phase
	SignalHub.match_phase_changed.emit(int(phase), int(previous))


## Seconds left on the match clock (never negative).
func remaining_time() -> float:
	return maxf(match_duration - match_elapsed, 0.0)


func is_running() -> bool:
	return phase == MatchPhase.RUNNING


func phase_name() -> String:
	return MatchPhase.keys()[phase] as String


## A player spawned into the match; returns the new alive count.
func notify_player_spawned() -> int:
	players_total += 1
	players_alive += 1
	return players_alive


## A player left the match (death, disconnect, elimination); returns alive count.
func notify_player_eliminated() -> int:
	players_alive = maxi(players_alive - 1, 0)
	return players_alive


## Clears everything for a fresh match / return to menu.
func reset() -> void:
	phase = MatchPhase.IDLE
	match_duration = 0.0
	match_elapsed = 0.0
	players_total = 0
	players_alive = 0
	tower_floor_count = 0
	local_player = null
