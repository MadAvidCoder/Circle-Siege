extends Node2D

@export var nominal_radius: float = 320
@export var thickness: float = 6
@export var smooth_factor: float = 0.18

var radius: float = nominal_radius

@onready var main = $".."
@onready var timer = $Timer

var bump: float = 1.0
var extra: float = 1.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0,0,0,0.2))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(0.9, 0.9, 1.0, 0.9), thickness, true)

func _process(_delta: float) -> void:
	queue_redraw()
	if !Config.reduced_motion:
		var target_radius = nominal_radius * (1 + 0.3 * main.energy)
		radius = lerp(radius, target_radius, smooth_factor) * bump #* extra
	else:
		radius = nominal_radius * 1.21 #* extra

func pulse():
	modulate = Config.colours["shockwave"].lightened(0.42)
	timer.start()
	var tween = get_tree().create_tween()
	tween.tween_property(self, "bump", 1.02, 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "bump", 1, 0.17).set_trans(Tween.TRANS_SINE)

func _on_timer_timeout() -> void:
	modulate = Color(1, 1, 1)
