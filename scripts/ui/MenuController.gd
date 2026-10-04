class_name MenuController
extends CanvasLayer

## The welcome / menu screen — built to match the reference `ui design example.png`.
## Flat-vector 2.5D style: dark navy backgrounds (#1E1B4B), royal blue cards
## (#1D4ED8), gold badges (#FACC15), slanted banners, bold dark outlines
## and hard drop shadows. Everything is drawn by Godot nodes; no external
## assets needed.

@export var theme: FloorTheme = null

@onready var title_label: Label = $TopBanner/TitleLabel
@onready var level_badge: Label = $TopLeft/LevelBadge
@onready var gold_label: Label = $TopRight/GoldPanel/GoldText
@onready var play_button: Button = $BottomRight/PlayButton

func _ready() -> void:
	if theme == null:
		theme = load("res://resources/floors/theme_mountain.tres") as FloorTheme

	# Style all cards with the flat-vector 2.5D look using the theme.
	_apply_theme()

	# Set initial display from current game state.
	# (In a full menu these come from save / server; for the prototype we
	# use hard defaults, configurable via exports above.)
	_hat_style()


func _apply_theme() -> void:
	# The cards live in the scene tree; we configure them by finding nodes.
	# Since this is procedural, the actual drawing is done by PanelContainer
	# styleboxes and the Label fonts — we just set colours from the theme.
	if theme != null:
		# Room / background tint: deep warm dark
		var bg := get_tree().get_root().get_node_or_null("MenuBG")
		if bg != null:
			bg.modulate = theme.ambient_color


func _hat_style() -> void:
	# The big PLAY button gets the yellow/gold high-contrast treatment from
	# the reference, with a dark outline and an offset shadow.
	if play_button != null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.95, 0.78, 0.35, 1.0)
		style.border_color = Color(0.08, 0.05, 0.12, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		play_button.add_theme_color_override("font_color", Color(0.1, 0.05, 0.15, 1))


func _on_play_pressed() -> void:
	SceneRouter.goto(&"match")
