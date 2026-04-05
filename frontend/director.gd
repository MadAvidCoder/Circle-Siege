extends Node2D

@export var gap_width_deg: float = 40.0  
@export var gap_margin_deg: float = 10.0
@export var min_gap_window: float = 0.75

@export var debug_draw_gap: bool = true
@export var debug_gap_alpha: float = 0.22

@export var radial_speed: float = 520.0
@export var chord_speed: float = 760.0
@export var telegraph_radial: float = 0.40
@export var telegraph_chord: float = 0.55

var projectile_scene = preload("res://Projectile.tscn")
var radial_telegraph_scene = preload("res://RadialTelegraph.tscn")
var chord_telegraph_scene = preload("res://ChordTelegraph.tscn")

@onready var arena = $"../Arena"
@onready var player = $"../Player"
@onready var telegraphs = $"../Telegraphs"
@onready var projectiles = $"../Projectiles"

var song_time = 0.0
var gap_centre = 0.0
var gap_until_t = 0.0

func _ready() -> void:
	gap_centre = (player.global_position - arena.global_position).angle()

func _process(delta: float) -> void:
	song_time += delta
	
	if song_time > gap_until_t:
		var target = (player.global_position - arena.global_position).angle()
		gap_centre = lerp_angle(gap_centre, target, 0.18)
		
	if debug_draw_gap:
		queue_redraw()
	
	if Input.is_action_just_pressed("ui_left"):
		lock_gap(1.0)
		spawn_radial(randf() * TAU)

	if Input.is_action_just_pressed("ui_right"):
		lock_gap(1.0)
		spawn_chord(randf() * TAU, randf() * TAU)


func lock_gap(time: float) -> void:
	gap_until_t = maxf(gap_until_t, song_time+maxf(time, min_gap_window))

func get_gap_width_rad() -> float:
	return deg_to_rad(gap_width_deg)

func get_gap_effective_width_rad() -> float:
	return deg_to_rad(gap_width_deg + 2.0 * gap_margin_deg)

func is_angle_in_gap(theta: float, t: float = -1.0) -> bool:
	if t < 0.0:
		t = song_time
	
	if t >= gap_until_t:
		return false
	
	var w = get_gap_effective_width_rad()
	var half = w * 0.5
	
	return absf(wrapf(theta - gap_centre, -PI, PI)) <= half

func nearest_angle_outside_gap(theta: float) -> float:
	var w = get_gap_effective_width_rad()
	var half = w * 0.5
	var d = wrapf(theta - gap_centre, -PI, PI)
	
	if absf(d) > half:
		return theta
	
	var sign = 1.0 if d >= 0.0 else -1.0
	var eps = deg_to_rad(0.5)
	return gap_centre + sign * (half + eps)

func _draw() -> void:
	if !debug_draw_gap:
		return
	
	var r = arena.radius
	var w = get_gap_effective_width_rad()
	var start = gap_centre - w * 0.5
	var end = gap_centre + w * 0.5
	
	var col = Color(0.2, 1.0, 0.2, debug_gap_alpha)
	
	var pts = []
	pts.append(Vector2.ZERO)

	for i in range(49):
		var a = lerpf(start, end, float(i) / float(48))
		pts.append(Vector2(cos(a), sin(a)) * r)
	
	draw_colored_polygon(pts, col)
	
	draw_arc(Vector2.ZERO, r, start, end, 64, Color(0.2, 1.0, 0.2, 0.9), 2.0, true)

func spawn_radial(theta: float) -> void:
	if is_angle_in_gap(theta):
		theta = nearest_angle_outside_gap(theta)
	
	var centre = arena.global_position
	var r = arena.radius
	var spawn_pos = centre + Vector2(cos(theta), sin(theta)) * r
	var inward = (centre - spawn_pos).normalized()
	
	var tg = radial_telegraph_scene.instantiate()
	telegraphs.add_child(tg)
	tg.setup(centre, spawn_pos, inward, projectile_scene, radial_speed, projectiles, telegraph_radial)

func spawn_chord(theta_a: float, theta_b: float) -> void:
	if is_angle_in_gap(theta_a):
		theta_a = nearest_angle_outside_gap(theta_a)
	if is_angle_in_gap(theta_b):
		theta_b = nearest_angle_outside_gap(theta_b)
	
	var centre = arena.global_position
	var r = arena.radius
	var a = centre + Vector2(cos(theta_a), sin(theta_a)) * r
	var b = centre + Vector2(cos(theta_b), sin(theta_b)) * r
	
	var tg = chord_telegraph_scene.instantiate()
	telegraphs.add_child(tg)
	tg.setup(a, b, projectile_scene, chord_speed, projectiles, telegraph_chord)
