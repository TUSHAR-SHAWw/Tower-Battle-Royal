extends TestCase

var _hud: HUD


func before_suite() -> void:
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	assert_not_null(hud_scene)
	if hud_scene == null:
		return
	_hud = hud_scene.instantiate() as HUD
	assert_not_null(_hud)
	if _hud == null:
		return
	get_tree().root.add_child.call_deferred(_hud)
	await get_tree().process_frame


func after_suite() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
		await get_tree().process_frame


func test_health_signal_updates_bar_and_text() -> void:
	SignalHub.player_health_changed.emit(null, 45.0, 100.0)
	assert_almost_eq(_hud.health_fill.value, 45.0)
	assert_eq(_hud.health_text.text, "45/100")


func test_hunger_and_rage_signals_update_bars() -> void:
	SignalHub.hunger_changed.emit(null, 25.0, 100.0)
	SignalHub.rage_changed.emit(null, 70.0, 100.0)
	assert_almost_eq(_hud.hunger_fill.value, 25.0)
	assert_eq(_hud.hunger_text.text, "HUNGER 25/100")
	assert_almost_eq(_hud.rage_fill.value, 70.0)
	assert_eq(_hud.rage_text.text, "RAGE 70/100")


func test_wave_and_floor_signals_update_labels() -> void:
	SignalHub.wave_started.emit(3, 7)
	SignalHub.tower_floor_changed.emit(7)
	assert_eq(_hud.wave_text.text, "WAVE 3")
	assert_eq(_hud.floor_text.text, "FLOOR 7")


func test_xp_and_notification_signals_update_hud() -> void:
	SignalHub.xp_changed.emit(125, 25)
	SignalHub.hud_notification.emit("Floor warning", &"warning")
	assert_eq(_hud.xp_text.text, "XP 125")
	assert_eq(_hud.notification.text, "Floor warning")
	assert_true(_hud.notification.visible)
