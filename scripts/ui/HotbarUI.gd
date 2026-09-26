class_name HotbarUI
extends Control

## Draws the 9-slot hotbar at screen bottom.
## Observes InventoryComponent via signals.

@export var inventory: InventoryComponent

var _slot_size: float = 64.0
var _padding: float = 8.0
var _background_color: Color = Color(0.0, 0.0, 0.0, 0.6)
var _border_color: Color = Color(1.0, 1.0, 1.0, 0.3)
var _selected_border_color: Color = Color(1.0, 0.8, 0.2, 1.0)
var _quantity_font: Font = null

func _ready() -> void:
	# Try to get default font
	_quantity_font = ThemeDB.get_default_theme().get_font("font", "Label")
	if _quantity_font == null:
		_quantity_font = FontFile.new()
	
	if inventory != null:
		inventory.hotbar_changed.connect(_on_hotbar_changed)
		inventory.item_added.connect(_on_item_changed)
		inventory.item_removed.connect(_on_item_changed)
		inventory.item_swapped.connect(_on_item_changed)
	
	# Set anchor to bottom center
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	
	# Make it full width, fixed height
	offset_left = -500
	offset_right = 500
	offset_top = -100
	offset_bottom = -20


func _on_hotbar_changed(slot: int) -> void:
	queue_redraw()


func _on_item_changed(slot: int, count: int = 1) -> void:
	if slot >= 0 and slot < InventoryComponent.HOTBAR_SIZE:
		queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	
	var hotbar_items := inventory.get_hotbar_items()
	var active := inventory.get_active_slot()
	
	var rect := get_rect()
	var screen_size := rect.size
	var start_x := (screen_size.x - (InventoryComponent.HOTBAR_SIZE * _slot_size + (InventoryComponent.HOTBAR_SIZE - 1) * _padding)) * 0.5
	var y := screen_size.y - _slot_size - 20.0
	
	for i in range(InventoryComponent.HOTBAR_SIZE):
		var slot_x := start_x + i * (_slot_size + _padding)
		var slot_rect := Rect2(slot_x, y, _slot_size, _slot_size)
		
		# Background
		draw_rect(slot_rect, _background_color)
		
		# Border
		var border_color := _border_color
		if i == active:
			border_color = _selected_border_color
		draw_rect(slot_rect, border_color, false, 2.0)
		
		# Item icon
		var item := hotbar_items[i]
		if item != null:
			var icon_color := item.icon_color
			if item.icon_texture != null:
				draw_texture(item.icon_texture, Vector2(slot_x + 8, y + 8), icon_color)
			else:
				# Draw placeholder colored square
				draw_rect(Rect2(slot_x + 8, y + 8, 48, 48), icon_color)
			
			# Quantity
			var qty := inventory.get_slot(i).quantity
			if qty > 1 and _quantity_font != null:
				var qty_text := str(qty)
				modulate = Color(1, 1, 1, 1)
				draw_string(_quantity_font, Vector2(slot_x + _slot_size - 20, y + _slot_size - 8), qty_text)
		
		# Slot number (1-9, 0=slot 9)
		var slot_num := str((i + 1) % 10)
		if _quantity_font != null:
			modulate = Color(1, 1, 1, 0.5)
			draw_string(_quantity_font, Vector2(slot_x + 4, y + 16), slot_num)


func get_hotbar_rect() -> Rect2:
	var rect := get_rect()
	var screen_size := rect.size
	var start_x := (screen_size.x - (InventoryComponent.HOTBAR_SIZE * _slot_size + (InventoryComponent.HOTBAR_SIZE - 1) * _padding)) * 0.5
	var y := screen_size.y - _slot_size - 20.0
	return Rect2(start_x, y, InventoryComponent.HOTBAR_SIZE * _slot_size + (InventoryComponent.HOTBAR_SIZE - 1) * _padding, _slot_size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		if inventory != null:
			inventory.hotbar_changed.disconnect(_on_hotbar_changed)
			inventory.item_added.disconnect(_on_item_changed)
			inventory.item_removed.disconnect(_on_item_changed)
			inventory.item_swapped.disconnect(_on_item_changed)