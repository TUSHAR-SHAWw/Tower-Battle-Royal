class_name HotbarUI
extends CanvasLayer

@export var inventory: InventoryComponent

const SLOT_SIZE := Vector2(44.0, 48.0)
const SLOT_GAP := 3.0

var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _quantities: Array[Label] = []


func _ready() -> void:
	var root := PixelArtScale.ensure_ui_root(self)
	_build_hotbar(root)
	if inventory != null:
		inventory.hotbar_changed.connect(_on_inventory_changed)
		inventory.item_added.connect(_on_item_changed)
		inventory.item_removed.connect(_on_item_changed)
		inventory.item_swapped.connect(_on_slots_swapped)
	_refresh_hotbar()


func _build_hotbar(root: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Slots"
	row.anchor_left = 0.5
	row.anchor_top = 1.0
	row.anchor_right = 0.5
	row.anchor_bottom = 1.0
	row.offset_left = -float(InventoryComponent.HOTBAR_SIZE) * (SLOT_SIZE.x + SLOT_GAP) * 0.5
	row.offset_right = float(InventoryComponent.HOTBAR_SIZE) * (SLOT_SIZE.x + SLOT_GAP) * 0.5 - SLOT_GAP
	row.offset_top = -SLOT_SIZE.y - 10.0
	row.offset_bottom = -10.0
	row.add_theme_constant_override("separation", int(SLOT_GAP))
	root.add_child(row)

	for index in range(InventoryComponent.HOTBAR_SIZE):
		var button := Button.new()
		button.name = "Slot_%d" % index
		button.custom_minimum_size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_slot_pressed.bind(index))
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.035, 0.05, 0.075, 0.78)
		normal.border_width_left = 2
		normal.border_width_top = 2
		normal.border_width_right = 2
		normal.border_width_bottom = 2
		normal.border_color = Color(0.32, 0.46, 0.62, 0.9)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.10, 0.16, 0.24, 0.98)
		hover.border_color = Color(0.55, 0.78, 1.0, 1.0)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.17, 0.14, 0.06, 0.98)
		pressed.border_color = Color(1.0, 0.82, 0.35, 1.0)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		row.add_child(button)
		_buttons.append(button)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5.0
		icon.offset_top = 9.0
		icon.offset_right = -5.0
		icon.offset_bottom = -6.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		_icons.append(icon)

		var number := Label.new()
		number.position = Vector2(5.0, 1.0)
		number.size = Vector2(16.0, 16.0)
		number.text = str((index + 1) % 10)
		number.add_theme_font_size_override("font_size", 11)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)

		var quantity := Label.new()
		quantity.anchor_left = 1.0
		quantity.anchor_top = 1.0
		quantity.anchor_right = 1.0
		quantity.anchor_bottom = 1.0
		quantity.offset_left = -24.0
		quantity.offset_top = -18.0
		quantity.offset_right = -3.0
		quantity.offset_bottom = -1.0
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.add_theme_font_size_override("font_size", 11)
		quantity.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		quantity.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1.0))
		quantity.add_theme_constant_override("outline_size", 3)
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(quantity)
		_quantities.append(quantity)


func _refresh_hotbar() -> void:
	if inventory == null:
		return
	for index in range(InventoryComponent.HOTBAR_SIZE):
		var slot := inventory.get_slot(index)
		var item: ItemResource = slot.item if slot != null else null
		var icon := _icons[index]
		icon.texture = MapAssetLibrary.item_texture(item) if item != null else null
		icon.modulate = item.icon_color if item != null else Color.WHITE
		_quantities[index].text = str(slot.quantity) if slot != null and slot.quantity > 1 else ""
		_buttons[index].modulate = Color(1.0, 0.84, 0.46) if index == inventory.get_active_slot() else Color.WHITE


func _on_slot_pressed(index: int) -> void:
	if inventory != null:
		inventory.set_active_slot(index)
	_refresh_hotbar()


func _on_inventory_changed(_active_slot: int) -> void:
	_refresh_hotbar()


func _on_item_changed(_item_id: StringName, _slot_index: int) -> void:
	_refresh_hotbar()


func _on_slots_swapped(_from_slot: int, _to_slot: int) -> void:
	_refresh_hotbar()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var slot := int(event.keycode) - int(KEY_1)
	if event.keycode == KEY_0:
		slot = 8
	if slot >= 0 and slot < InventoryComponent.HOTBAR_SIZE:
		_on_slot_pressed(slot)
		get_viewport().set_input_as_handled()


func get_hotbar_rect() -> Rect2:
	var width := InventoryComponent.HOTBAR_SIZE * SLOT_SIZE.x + (InventoryComponent.HOTBAR_SIZE - 1) * SLOT_GAP
	return Rect2((PixelArtScale.DESIGN_SIZE.x - width) * 0.5, PixelArtScale.DESIGN_SIZE.y - SLOT_SIZE.y - 10.0, width, SLOT_SIZE.y)


func _exit_tree() -> void:
	if inventory == null:
		return
	if inventory.hotbar_changed.is_connected(_on_inventory_changed):
		inventory.hotbar_changed.disconnect(_on_inventory_changed)
	if inventory.item_added.is_connected(_on_item_changed):
		inventory.item_added.disconnect(_on_item_changed)
	if inventory.item_removed.is_connected(_on_item_changed):
		inventory.item_removed.disconnect(_on_item_changed)
	if inventory.item_swapped.is_connected(_on_slots_swapped):
		inventory.item_swapped.disconnect(_on_slots_swapped)
