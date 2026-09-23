extends TestCase

## ObjectPool will carry every projectile and element effect in a match, so its
## contract is pinned before any gun exists: accounting, instance reuse, and the
## guarantee that an idle pooled node costs nothing.
##
## Two tests intentionally trigger push_error()/push_warning() (releasing a node
## the pool does not own, and requesting an unknown state elsewhere). Those log
## lines are expected behaviour, not failures.

var _host: Node2D


func before_each() -> void:
	_host = Node2D.new()
	_host.name = "PoolHost"
	add_child(_host)  # parented to the suite so it is always freed


func after_each() -> void:
	if _host != null:
		_host.queue_free()
		_host = null


func test_acquire_returns_a_live_child() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var node := pool.acquire()
	assert_not_null(node, "acquire() must always return a node")
	assert_true(_host.is_ancestor_of(node), "pooled nodes must live under the pool's parent")
	assert_eq(pool.active_count(), 1)
	assert_eq(pool.available_count(), 0)


func test_acquire_twice_returns_distinct_instances() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var first := pool.acquire()
	var second := pool.acquire()
	assert_ne(first.get_instance_id(), second.get_instance_id(), "two live projectiles must not share a node")


func test_released_instance_is_reused() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var first := pool.acquire()
	pool.release(first)
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.available_count(), 1)
	var second := pool.acquire()
	assert_eq(second.get_instance_id(), first.get_instance_id(), "the pool must recycle instead of instancing")


func test_release_disables_processing_and_visibility() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var node := pool.acquire()
	pool.release(node)
	assert_false((node as CanvasItem).visible, "a pooled node must be hidden")
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, "a pooled node must not tick")


func test_acquire_restores_processing_and_visibility() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var node := pool.acquire()
	pool.release(node)
	var again := pool.acquire()
	assert_true((again as CanvasItem).visible)
	assert_eq(again.process_mode, Node.PROCESS_MODE_INHERIT)


func test_collision_is_switched_off_while_pooled() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var node := pool.acquire() as Area2D
	await get_tree().physics_frame
	assert_true(node.monitoring, "an active projectile must detect hits")

	pool.release(node)
	await get_tree().physics_frame
	assert_false(node.monitoring, "a pooled projectile must not detect hits")

	pool.acquire()
	await get_tree().physics_frame
	assert_true(node.monitoring, "re-acquiring must re-arm collision")


func test_pool_callbacks_fire_on_acquire_and_release() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var node := pool.acquire() as PoolStub
	assert_eq(node.acquire_count, 1, "_on_pool_acquire is where a projectile resets itself")
	pool.release(node)
	assert_eq(node.release_count, 1, "_on_pool_release is where a projectile cleans up")


func test_prewarm_instantiates_up_front() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host, 3)
	assert_eq(pool.available_count(), 3, "prewarmed instances are created before they are needed")
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.spawned_count(), 3)

	pool.acquire()
	assert_eq(pool.available_count(), 2)
	assert_eq(pool.spawned_count(), 3, "acquiring must not instantiate past the prewarm")


func test_releasing_a_foreign_node_is_refused() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	var stranger := PoolStub.new()
	add_child(stranger)
	pool.release(stranger)
	assert_eq(pool.available_count(), 0, "a node the pool does not own must never enter its pool")
	assert_eq(pool.active_count(), 0)


func test_release_all_returns_everything() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	pool.acquire()
	pool.acquire()
	pool.acquire()
	pool.release_all()
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.available_count(), 3)


func test_release_null_is_a_no_op() -> void:
	var pool := ObjectPool.new(_stub_scene(), _host)
	pool.release(null)
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.available_count(), 0)


# ----------------------------------------------------------------------- helpers

func _stub_scene() -> PackedScene:
	var stub := PoolStub.new()
	stub.name = "PoolStub"
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	stub.add_child(shape)
	var packed := PackedScene.new()
	var error := packed.pack(stub)
	stub.free()
	if error != OK:
		fail("could not pack the PoolStub fixture (error %d)" % error)
		return null
	return packed
