class_name CheatConsole
extends CanvasLayer

## In-game developer console (F10 by default).
##
## Commands are registered by the systems that own them through
## `DevTools.register_command()`, so this file never learns about weapons,
## floors, hunger or rage. That keeps cheat tooling from becoming a second,
## hidden gameplay codebase.
##
## Handlers receive the raw argument tokens as PackedStringArray and return a
## String (empty = nothing to print).

const HISTORY_LINES := 200

@export var toggle_action: StringName = &"debug_toggle_console"

var _panel: PanelContainer
var _history: RichTextLabel
var _input: LineEdit
var _commands: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(toggle_action):
		return
	set_open(not is_open())
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------ public

func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(open: bool) -> void:
	if _panel == null:
		return
	_panel.visible = open
	if open:
		_input.grab_focus()
	else:
		_input.text = ""
		_input.release_focus()


## `handler` must accept exactly one PackedStringArray argument.
func register_command(command_name: StringName, handler: Callable, help_text: String, usage: String = "") -> void:
	if handler.get_argument_count() != 1:
		push_error("CheatConsole: handler for '%s' must take exactly one PackedStringArray argument." % command_name)
		return
	_commands[command_name] = {
		"callable": handler,
		"help": help_text,
		"usage": usage if not usage.is_empty() else String(command_name),
	}


func has_command(command_name: StringName) -> bool:
	return _commands.has(command_name)


func command_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: Variant in _commands.keys():
		names.append(StringName(key))
	# StringName's native ordering is not alphabetical, so compare as Strings.
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return names


func command_usage(command_name: StringName) -> String:
	if not _commands.has(command_name):
		return ""
	var entry: Dictionary = _commands[command_name]
	return "%s — %s" % [entry["usage"], entry["help"]]


func command_summary() -> String:
	var lines: Array[String] = ["commands:"]
	for command_name: StringName in command_names():
		lines.append("  %s" % command_usage(command_name))
	return "\n".join(PackedStringArray(lines))


func log_line(text: String, kind: StringName = &"info") -> void:
	if _history == null or text.is_empty():
		return
	_history.append_text("[color=%s]%s[/color]\n" % [_color_for(kind), text])
	_trim_history()


func clear_history() -> void:
	if _history != null:
		_history.clear()


# ----------------------------------------------------------------------- private

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 8.0
	_panel.offset_right = -8.0
	_panel.offset_top = -220.0
	_panel.offset_bottom = -8.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.85)
	style.border_color = Color(0.45, 0.75, 1.0, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)

	_history = RichTextLabel.new()
	_history.name = "History"
	_history.bbcode_enabled = true
	_history.scroll_following = true
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history.add_theme_font_size_override("normal_font_size", 12)
	column.add_child(_history)

	_input = LineEdit.new()
	_input.name = "Input"
	_input.placeholder_text = "type a command, then Enter (F10 closes)"
	_input.text_submitted.connect(_on_text_submitted)
	column.add_child(_input)

	_panel.add_child(column)
	add_child(_panel)


func _on_text_submitted(text: String) -> void:
	_submit(text)


func _submit(text: String) -> void:
	_input.text = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	log_line("> %s" % trimmed, &"echo")

	var tokens := trimmed.split(" ", false)
	var command_name := StringName(tokens[0].to_lower())
	if not has_command(command_name):
		log_line("unknown command '%s' — try 'help'" % command_name, &"error")
		return

	var args := PackedStringArray()
	for i: int in range(1, tokens.size()):
		args.append(tokens[i])

	var handler: Callable = _commands[command_name]["callable"]
	var result: Variant = handler.call(args)
	if result is String and not (result as String).is_empty():
		log_line(result as String, &"result")


func _trim_history() -> void:
	if _history.get_line_count() <= HISTORY_LINES:
		return
	# RichTextLabel cannot drop single lines, so rebuild from the tail.
	var lines := _history.get_parsed_text().split("\n", true)
	var keep := PackedStringArray()
	for i: int in range(maxi(lines.size() - HISTORY_LINES, 0), lines.size()):
		keep.append(lines[i])
	clear_history()
	_history.append_text("\n".join(keep))


func _color_for(kind: StringName) -> String:
	match kind:
		&"error":
			return "#ff8b8b"
		&"echo":
			return "#7f8ea3"
		&"result":
			return "#8ee6a0"
		&"warning":
			return "#ffd479"
		_:
			return "#cfe3ff"
