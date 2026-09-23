class_name PoolStub
extends Area2D

## Test fixture for ObjectPool: a minimal poolable node that counts the pool
## callbacks, so the lifecycle contract can be verified without a real projectile
## or weapon scene existing yet.

var acquire_count: int = 0
var release_count: int = 0


func _on_pool_acquire() -> void:
	acquire_count += 1


func _on_pool_release() -> void:
	release_count += 1
