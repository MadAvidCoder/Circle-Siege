extends CharacterBody2D

@export var max_accel: float = 10000.0
@export var max_speed: float = 1700.0
@export var slow_radius: float = 180.0
@export var stop_radius: float = 10.0

@export var vel_gain: float = 14.0
@export var spring_gain: float = 22.0
@export var damping: float = 3.0

@onready var arena_radius = $"../Arena".radius
@onready var player_size = $Sprite2D.get_rect().size.x
@onready var near_miss_fx = $NearMissFX

var lives = 3

func _physics_process(delta: float) -> void:
	var mouse = get_global_mouse_position()
	var to_mouse = mouse - global_position
	var dist = to_mouse.length()
	var dir = to_mouse / maxf(dist, 0.0001)

	var x = clampf((dist - stop_radius) / slow_radius, 0.0, 1.0)
	var smooth = x * x * (3.0 - 2.0 * x)
	var desired_speed = max_speed * smooth
	var desired_vel = dir * desired_speed

	var a_vel = (desired_vel - velocity) * vel_gain
	var a_spring = dir * (spring_gain * dist)
	var a_damp = -velocity * damping

	var accel = a_vel + a_spring + a_damp

	var a_len = accel.length()
	if a_len > max_accel:
		accel = accel * (max_accel / a_len)

	velocity += accel * delta
	move_and_slide()

func _on_near_miss_area_entered(area: Area2D) -> void:
	if !area.is_in_group("projectiles"):
		return
	if area.near_missed:
		return
	
	area.near_missed = true
	near_miss_fx.trigger()
