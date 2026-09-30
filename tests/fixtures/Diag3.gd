extends Node

func _ready() -> void:
	var match_scene: PackedScene = load("res://scenes/main/Match.tscn") as PackedScene
	var m := match_scene.instantiate()
	get_tree().root.add_child.call_deferred(m)
	for i in range(12):
		await get_tree().physics_frame
	var p = m.get_node_or_null("PlayerInstance")
	var spr = p.get_node_or_null("Visual/Sprite")
	var vis = p.get_node_or_null("Visual")
	print("DIAG drawn_height=", vis.drawn_height(), " sprite scale=", spr.scale if spr != null else "null")
	if spr != null and spr.sprite_frames != null:
		var t = spr.sprite_frames.get_frame_texture(&"idle", 0)
		print("DIAG frame=", t, " size=", t.get_size() if t != null else "null")
		if t is AtlasTexture:
			print("DIAG region=", t.region, " atlas size=", t.atlas.get_size() if t.atlas != null else "null")
	# walk test
	var mv = p.get_node("MovementComponent")
	var sm = p.get_node("StateMachine")
	var before = p.global_position.x
	for i in range(20):
		mv.accelerate_toward(Vector2.RIGHT, 620.0, 4200.0, 1.0/60.0)
		mv.commit()
		await get_tree().physics_frame
	print("DIAG moved ", before, " -> ", p.global_position.x, " speed=", mv.speed(), " state=", sm.current_state_name())
	get_tree().quit(0)
