class_name PlayerStateUtil
extends RefCounted

## Shared helpers for the player state scripts.
##
## Exists because Idle/Move/Sprint all need the same two things: find the
## PlayerConfig on the host, and forward jump intent to the movement component.
## Copy-pasting that into each state is how the config lookup drifted out of
## sync with the Player scene in the first place.


## Resolves the PlayerConfig the host Player is configured with.
##
## The config is a resource export on Player.gd, NOT a child node — reading it
## from a node called "PlayerConfig" (which does not exist) silently yielded null
## and made the player unable to move.
static func resolve_config(host: Node) -> PlayerConfig:
	if host == null:
		return null
	var value: Variant = host.get("config")
	if value is PlayerConfig:
		return value as PlayerConfig
	# Fallback for hosts that wrap the config in a node.
	var config_node := host.get_node_or_null("PlayerConfig")
	if config_node != null:
		var res: Variant = config_node.get("resource")
		if res is PlayerConfig:
			return res as PlayerConfig
	push_warning("PlayerStateUtil: no PlayerConfig on %s" % host.name)
	return null


## Resolves the InputSource that is currently driving the host.
##
## This exists because an InputSource can be REPLACED at runtime — bots attach a
## BotInputDriver, a networked player swaps in a NetworkInputDriver and removes it
## on disconnect, a test installs a scripted source. The states used to cache the
## reference in `enter()`, so a replaced source was ignored until the player
## happened to leave and re-enter the state: the actor would simply stop
## responding to input, with nothing in the log to explain it.
##
## Resolved fresh every frame instead, which also means an `input_source` export
## assigned from code takes effect immediately.
##
## Falls back to the host's export when the child node is missing, and returns null
## when neither resolves, so callers can treat "no input" as a real state.
static func resolve_input(host: Node) -> InputSource:
	if host == null:
		return null
	var node := host.get_node_or_null("InputSource") as InputSource
	if node != null:
		return node
	var value: Variant = host.get("input_source")
	if value is InputSource:
		return value as InputSource
	return null


## Feeds jump intent into the movement component.
##
## `request_jump` buffers the press; `set_jump_held` drives variable jump height.
static func apply_vertical(movement: MovementComponent, intent: InputIntent) -> void:
	if movement == null or intent == null:
		return
	if intent.jump_pressed:
		movement.request_jump()
	movement.set_jump_held(intent.jump_held)


## Creates or reuses a Hurtbox Area2D on `host` and sizes its collider.
##
## Melee and projectiles find actors by their hurtbox: they mask PLAYER_HURTBOX /
## ENEMY_HURTBOX and climb from the Area2D to the actor that owns it. An actor
## without a hurtbox is therefore invulnerable, and an actor whose hurtbox has no
## CollisionShape2D silently does nothing — which is exactly how melee and bullets
## both ended up unable to damage the player. Doing this in code (rather than only
## in the .tscn) keeps the layer and the shape in one place.
static func ensure_hurtbox(host: Node2D, radius: float) -> Area2D:
	if host == null:
		return null
	var hurtbox := host.get_node_or_null("Hurtbox") as Area2D
	if hurtbox == null:
		hurtbox = Area2D.new()
		hurtbox.name = "Hurtbox"
		host.add_child(hurtbox)
	# Hurtboxes are listened to, never listening: layer = who I am, mask = nobody.
	hurtbox.collision_layer = PhysicsLayers.PLAYER_HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.monitorable = true
	hurtbox.monitoring = false

	var shape := hurtbox.get_node_or_null("HurtboxShape") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "HurtboxShape"
		hurtbox.add_child(shape)
	var circle := shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape.shape = circle
	circle.radius = radius
	return hurtbox
