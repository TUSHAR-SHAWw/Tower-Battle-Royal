class_name CheatPanel
extends Control

## Visual cheat panel (mod menu) with buttons for all cheat commands.
## Toggle with F10 (same as cheat console).

signal panel_toggled(visible: bool)

@export var dev_tools: DevTools

var _visible: bool = false
var _categories: Dictionary = {}
var _main_vbox: VBoxContainer = null

func _ready() -> void:
	# Hide by default
	visible = false
	_visible = false
	
	# Setup UI
	_setup_ui()
	
	# Register all commands from DevTools as buttons
	_populate_buttons()
	
	# Listen for toggle key
	if dev_tools != null and dev_tools.cheat_console != null:
		dev_tools.cheat_console.hook_key_pressed(KEY_F10)


func _setup_ui() -> void:
	# Main panel
	var panel := PanelContainer.new()
	panel.name = "CheatPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 200
	panel.offset_top = 100
	panel.offset_right = -200
	panel.offset_bottom = -100
	panel.add_theme_stylebox_override("panel", _make_stylebox())
	add_child(panel)
	
	# Scroll container for content
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	# Main VBox for categories
	var vbox := VBoxContainer.new()
	vbox.name = "Categories"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	# Header
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "TOWER BATTLE ROYALE - CHEAT PANEL"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
	header.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "✕ CLOSE (F10)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)
	vbox.add_child(header)
	
	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)


func _make_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	sb.border_color = Color(0.2, 0.6, 1.0, 1.0)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


func _populate_buttons() -> void:
	if dev_tools == null or dev_tools.cheat_console == null:
		return
	
	_main_vbox = get_node("CheatPanel/Scroll/Categories")
	if _main_vbox == null:
		return
	
	# Define categories and their commands
	var categories := {
		"PLAYER": [
			{"name": "Heal 100", "cmd": "heal 100", "help": "Heal player to full"},
			{"name": "Damage 50", "cmd": "damage 50", "help": "Take 50 damage"},
			{"name": "Set Health 100", "cmd": "set_health 100", "help": "Set health to 100"},
			{"name": "Set Health 1", "cmd": "set_health 1", "help": "Set health to 1 (near death)"},
			{"name": "Add Gold 1000", "cmd": "gold 1000", "help": "Add 1000 gold"},
			{"name": "Add Gold 10000", "cmd": "gold 10000", "help": "Add 10000 gold"},
			{"name": "Give Health Pack x5", "cmd": "give_item health_pack 5", "help": "Give 5 health packs"},
			{"name": "Give Adrenaline x3", "cmd": "give_item adrenaline 3", "help": "Give 3 adrenaline"},
			{"name": "Speed Boost 2x 10s", "cmd": "speed_boost 2 10", "help": "2x speed for 10 seconds"},
			{"name": "Speed Boost 5x 30s", "cmd": "speed_boost 5 30", "help": "5x speed for 30 seconds"},
			{"name": "Set Hunger 100", "cmd": "set_hunger 100", "help": "Full hunger"},
			{"name": "Set Hunger 0", "cmd": "set_hunger 0", "help": "Starving"},
			{"name": "Set Rage 100", "cmd": "set_rage 100", "help": "Max rage (triggers rage mode)"},
			{"name": "Set Rage 0", "cmd": "set_rage 0", "help": "Zero rage"},
			{"name": "Toggle Invincible", "cmd": "invincible toggle", "help": "Toggle invincibility"},
			{"name": "Invincible On", "cmd": "invincible on", "help": "Enable invincibility"},
			{"name": "Invincible Off", "cmd": "invincible off", "help": "Disable invincibility"},
		],
		"INVENTORY": [
			{"name": "Show Inventory", "cmd": "inv", "help": "Show inventory debug"},
			{"name": "Trigger Merge", "cmd": "merge", "help": "Start merge with first recipe"},
			{"name": "Trigger Craft", "cmd": "craft", "help": "Start craft with first recipe"},
		],
		"ELEMENTAL": [
			{"name": "Apply Burn 10s", "cmd": "apply_status fire 10", "help": "Apply burn for 10s"},
			{"name": "Apply Freeze 5s", "cmd": "apply_status ice 5", "help": "Apply freeze for 5s"},
			{"name": "Apply Shock 5s", "cmd": "apply_status lightning 5", "help": "Apply shock for 5s"},
			{"name": "Apply Poison 15s", "cmd": "apply_status poison 15", "help": "Apply poison for 15s"},
			{"name": "Clear All Status", "cmd": "clear_status", "help": "Remove all elemental statuses"},
		],
		"TOWER / FLOOR": [
			{"name": "Show Current Floor", "cmd": "floor", "help": "Display current floor"},
			{"name": "Go to Floor 1", "cmd": "travel 1", "help": "Travel to floor 1"},
			{"name": "Go to Floor 2", "cmd": "travel 2", "help": "Travel to floor 2"},
			{"name": "Floor State: ACTIVE", "cmd": "floor_state ACTIVE", "help": "Set floor to active"},
			{"name": "Floor State: WARNING", "cmd": "floor_state WARNING", "help": "Set floor to warning"},
			{"name": "Floor State: COLLAPSING", "cmd": "floor_state COLLAPSING", "help": "Set floor to collapsing"},
			{"name": "Delete Current Floor", "cmd": "delete_floor", "help": "Start floor deletion"},
			{"name": "Spawn Portal to Next", "cmd": "portal", "help": "Spawn travel portal at player"},
		],
		"MISC": [
			{"name": "Spawn Loot Chest", "cmd": "spawn_chest", "help": "Spawn chest at player"},
			{"name": "Kill All Enemies", "cmd": "kill_all", "help": "Kill all enemies on floor"},
			{"name": "Toggle Noclip", "cmd": "noclip toggle", "help": "Toggle noclip mode"},
			{"name": "Time Scale 0.5x", "cmd": "timescale 0.5", "help": "Half speed"},
			{"name": "Time Scale 1.0x", "cmd": "timescale 1.0", "help": "Normal speed"},
			{"name": "Time Scale 2.0x", "cmd": "timescale 2.0", "help": "Double speed"},
			{"name": "Time Scale 0.1x", "cmd": "timescale 0.1", "help": "Slow motion"},
			{"name": "Print Game State", "cmd": "state", "help": "Show match state"},
			{"name": "Print Routes", "cmd": "routes", "help": "List scene routes"},
		],
	}
	
	for category_name in categories:
		_add_category(category_name, categories[category_name])


func _add_category(category: String, commands: Array) -> void:
	# Category header
	var cat_vbox := VBoxContainer.new()
	cat_vbox.add_theme_constant_override("separation", 8)
	
	var cat_label := Label.new()
	cat_label.text = "== %s ==" % category
	cat_label.add_theme_font_size_override("font_size", 18)
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1))
	cat_vbox.add_child(cat_label)
	
	# Button grid (2 columns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	cat_vbox.add_child(grid)
	
	for cmd_info in commands:
		var btn := Button.new()
		btn.text = cmd_info.name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.tooltip_text = cmd_info.help
		btn.pressed.connect(_on_button_pressed.bind(cmd_info.cmd))
		grid.add_child(btn)
	
	_main_vbox.add_child(cat_vbox)


func _on_button_pressed(cmd: String) -> void:
	if dev_tools != null and dev_tools.cheat_console != null:
		dev_tools.cheat_console.execute_command(cmd)


func _on_close_pressed() -> void:
	_toggle_panel()


func _toggle_panel() -> void:
	_visible = not _visible
	visible = _visible
	panel_toggled.emit(_visible)
	
	if _visible:
		# Bring to front
		move_child(get_node("CheatPanel"), -1)
		grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_toggle_panel()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Ensure we're on top
		call_deferred("_ensure_top")


func _ensure_top() -> void:
	if _visible:
		move_child(get_node("CheatPanel"), -1)