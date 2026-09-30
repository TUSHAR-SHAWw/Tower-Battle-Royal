class_name NetworkInputDriver
extends InputSource

## Reconstructs InputIntent from queued NetPlayerInput messages.
##
## In networked play, inputs are collected on the client, sent to the server,
## the server simulates them, and snapshots are sent back. On the client,
// this driver replays the input queue so prediction works identically to
// local input.

var _input_queue: Array[NetMessage.NetPlayerInput] = []
var _queue_head: int = 0
var _last_applied_seq: int = -1


func _init() -> void:
	set_process(false)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_local() -> bool:
	return false


## Called by the client to queue an input message received from the server
## (or by the server to apply its own received inputs).
func queue_input(msg: NetMessage.NetPlayerInput) -> void:
	_input_queue.append(msg)


func _read_input(intent: InputIntent, _host: Node2D) -> void:
	if _queue_head >= _input_queue.size():
		return

	var msg := _input_queue[_queue_head]
	if msg.input_sequence <= _last_applied_seq:
		_queue_head += 1
		if _queue_head >= _input_queue.size():
			_queue_head = 0
			_input_queue.clear()
		return

	_last_applied_seq = msg.input_sequence
	intent.move_dir = msg.move_dir
	intent.aim_dir = msg.aim_dir.normalized()
	if msg.aim_dir.length() < 0.01:
		intent.aim_dir = Vector2.RIGHT

	intent.sprint_held = msg.sprint_held
	intent.fire_held = msg.fire_held
	intent.fire_pressed = msg.fire_pressed
	intent.reload_pressed = msg.reload_pressed
	intent.melee_pressed = msg.melee_pressed
	intent.interact_pressed = msg.use_pressed
	intent.use_pressed = false
	intent.map_pressed = false
	intent.merge_pressed = false
	intent.requested_slot = -1

	_queue_head += 1
	if _queue_head >= _input_queue.size():
		_queue_head = 0
		_input_queue.clear()


func clear_queue() -> void:
	_input_queue.clear()
	_queue_head = 0
	_last_applied_seq = -1


func has_pending_inputs() -> bool:
	return _queue_head < _input_queue.size()
