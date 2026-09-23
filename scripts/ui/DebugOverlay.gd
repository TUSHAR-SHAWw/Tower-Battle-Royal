class_name DebugOverlay
extends CanvasLayer

## Toggleable developer HUD (F3 by default).
##
## Shows engine stats plus any line a system registered through
## `DevTools.register_provider()`. The overlay knows nothing about gameplay, so
## new systems can expose debug values without editing this file.
##
## Refreshes at REFRESH_INTERVAL instead of every frame — the HUD must not become
## the reason the game is slow (master prompt §52).

const REFRESH_INTERVAL := 0.2

@export var toggle_action: StringName = &"debug_toggle_overlay"
@export var start_visible: bool = true

var _panel: PanelContainer
var _label: RichTextLabel
var _provider_labels: Array[String] = []
var _provider_callables: Array[Callable] = []
var _refresh_timer: float = 0.0


func _ready() -> void:
	layer = 100
	# Keep working while the game is paused; a paused game is when it matters most.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = start_visible
	_refresh_timer = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	_redraw()


# ------------------------------------------------------------------------ public

## `provider` must return a String; it is called at most once per refresh.
func register_provider(label: String, provider: Callable) -> void:
	_provider_labels.append(label)
	_provider_callables.append(provider)


func clear_providers() -> void:
	_provider_labels.clear()
	_provider_callables.clear()


# ----------------------------------------------------------------------- private

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 8.0
	_panel.offset_top = 8.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.62)
	style.border_color = Color(0.45, 0.75, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6.0)
	_panel.add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.name = "Text"
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size = Vector2(380.0, 0.0)
	_label.add_theme_font_size_override("normal_font_size", 12)
	_panel.add_child(_label)

	add_child(_panel)


func _redraw() -> void:
	var lines: Array[String] = []
	var fps := Engine.get_frames_per_second()
	lines.append("TBR dev  |  Godot %s" % Engine.get_version_info().get("string", "?"))
	lines.append("FPS %d   nodes %d" % [fps, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	for i: int in _provider_labels.size():
		var label := _provider_labels[i]
		if not _provider_callables[i].is_valid():
			continue
		lines.append("%s: %s" % [label, str(_provider_callables[i].call())])
	_label.text = "\n".join(PackedStringArray(lines))
