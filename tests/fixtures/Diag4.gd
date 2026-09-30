extends Node

## Reproduces the test harness exactly: settle, then drive, and report why the
## walk test sees zero movement.
var drv: ScriptedInputSource
var p: Node
var sm: StateMachine
var mv: MovementComponent

func _ready() -> void:
	var ms: PackedScene = load("res://scenes/main/Match.tscn") as PackedScene
	var m := ms.instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p = m.get_node_or_null("PlayerInstance")
	var old = p.get_node_or_null("InputSource")
	if old != null:
		p.remove_child(old); old.free()
	drv = ScriptedInputSource.new()
	drv.name = "InputSource"
	p.add_child(drv)
	p.set("input_source", drv)
	sm = p.get_node("StateMachine")
	mv = p.get_node("MovementComponent")

	# --- exactly what before_each() now does ---
	var spawn = p.global_position
	print("DIAG spawn=", spawn)
	for t in range(4):
		p.global_position = spawn
		p.velocity = Vector2.ZERO
		drv.scripted.reset()
		if sm.has_state(&"idle"):
			sm.transition_to(&"idle")
		await settle()
		print("DIAG trial", t, " settled pos=", p.global_position, " state=", sm.current_state_name(), " on_floor=", p.is_on_floor())
		var x0 = p.global_position.x
		for n in range(30):
			drv.scripted.reset()
			drv.scripted.move_dir = Vector2.RIGHT
			await get_tree().physics_frame
		print("DIAG trial", t, " dx=", p.global_position.x - x0, " state=", sm.current_state_name(), " vel=", p.velocity)
	get_tree().quit(0)

func settle(max_frames: int = 90) -> void:
	for _i in range(max_frames):
		await get_tree().physics_frame
		if p.is_on_floor() and mv.speed() < 5.0:
			break
	drv.scripted.reset()
	await get_tree().physics_frame
