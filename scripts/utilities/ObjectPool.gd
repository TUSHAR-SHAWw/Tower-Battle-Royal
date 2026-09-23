class_name ObjectPool
extends RefCounted

## Recycles scene instances instead of instancing and freeing them constantly.
##
## Guns and element effects will spawn hundreds of nodes per match; instancing
## during combat is exactly the kind of thing that causes frame spikes on phones
## (master prompt §52). Projectiles are the first user (M3).
##
## Contract for pooled scenes:
##   * optional `_on_pool_acquire()` — reset velocity, timers, trail, ...
##   * optional `_on_pool_release()` — stop sounds, hide effects, ...
## Nodes stay in the tree while pooled, but are hidden, have processing disabled
## and have their collision switched off.

var _scene: PackedScene
var _parent: Node
var _name_prefix: String
var _available: Array[Node] = []
var _active: Array[Node] = []
var _next_id: int = 0


## `prewarm` instantiates instances up front so the first shot never stutters.
func _init(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
	_scene = scene
	_parent = parent
	_name_prefix = "Pooled"
	if scene != null and not scene.resource_path.is_empty():
		_name_prefix = scene.resource_path.get_file().get_basename()
	if scene == null:
		push_error("ObjectPool: created with a null scene; acquire() will fail.")
		return
	if parent == null:
		push_error("ObjectPool: created with a null parent; acquire() will fail.")
		return
	for _i: int in maxi(prewarm, 0):
		var node := _instantiate()
		_deactivate(node)
		_available.append(node)


## Borrows an instance. Always returns a live node, or null if misconfigured.
func acquire() -> Node:
	if _scene == null or _parent == null:
		return null
	var node: Node = _available.pop_back() if not _available.is_empty() else _instantiate()
	if node == null:
		return null
	_active.append(node)
	_activate(node)
	return node


func release(node: Node) -> void:
	if node == null:
		return
	if not _active.has(node):
		push_error("ObjectPool: release() called for a node this pool does not own (%s)." % node)
		return
	_active.erase(node)
	_deactivate(node)
	_available.append(node)


func release_all() -> void:
	for node: Node in _active.duplicate():
		release(node)


func active_count() -> int:
	return _active.size()


func available_count() -> int:
	return _available.size()


func spawned_count() -> int:
	return _active.size() + _available.size()


func debug_line() -> String:
	return "%s active=%d idle=%d" % [_name_prefix, active_count(), available_count()]


# ----------------------------------------------------------------------- private

func _instantiate() -> Node:
	if _scene == null or _parent == null:
		return null
	_next_id += 1
	var node := _scene.instantiate()
	node.name = "%s%d" % [_name_prefix, _next_id]
	_parent.add_child(node)
	return node


func _activate(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	_set_collision(node, true)
	if node.has_method(&"_on_pool_acquire"):
		node.call(&"_on_pool_acquire")


func _deactivate(node: Node) -> void:
	if node.has_method(&"_on_pool_release"):
		node.call(&"_on_pool_release")
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	# DISABLED also stops child timers, so a pooled projectile cannot keep ticking.
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_set_collision(node, false)


func _set_collision(node: Node, enabled: bool) -> void:
	if node is Area2D:
		var area := node as Area2D
		area.set_deferred(&"monitoring", enabled)
		area.set_deferred(&"monitorable", enabled)
		return
	if node is CollisionObject2D:
		# Bodies keep their shape nodes; only the collision is toggled.
		for child: Node in (node as CollisionObject2D).get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred(&"disabled", not enabled)
