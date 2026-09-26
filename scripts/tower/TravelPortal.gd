class_name TravelPortal
extends Area2D

## Portal that triggers floor travel when player enters.
## Visual: pulsing ring + particle effect.

signal activated(player: Node)

@export var target_floor: int = 0  # 0 = next floor
@export var activation_radius: float = 64.0
@export var cooldown: float = 2.0

var _active: bool = true
var _cooldown_timer: float = 0.0
var _pulse_phase: float = 0.0

func _ready() -> void:
	monitoring = _active
	monitorable = false
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	
	# Create collision shape
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = activation_radius
	shape.shape = circle
	add_child(shape)
	shape.owner = self
	
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _active:
		_cooldown_timer = max(0.0, _cooldown_timer - delta)
		if _cooldown_timer <= 0.0:
			_active = true
			monitoring = true
	
	_pulse_phase += delta * 3.0
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area.get_instance_id() == get_parent().get_instance_id():
		return
	
	if area.is_in_group("player") or area.has_method("take_damage"):
		_active = false
		monitoring = false
		_cooldown_timer = cooldown
		activated.emit(area)


func _draw() -> void:
	if not _active:
		return
	
	var pulse := sin(_pulse_phase) * 0.3 + 0.7
	var color := Color(0.2, 0.8, 1.0, pulse)
	var radius := activation_radius * (0.8 + pulse * 0.2)
	
	draw_circle(Vector2.ZERO, radius, color, false, 3.0)
	draw_circle(Vector2.ZERO, radius * 0.7, color, false, 2.0)
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1, 1, 1, pulse * 0.5))