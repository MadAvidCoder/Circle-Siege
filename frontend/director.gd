extends Node2D

@export var gap_width_deg: float = 40.0 
var min_gap = 28
var max_gap = 60 
@export var gap_margin_deg: float = 10.0
@export var min_gap_window: float = 0.75

@export var debug_draw_gap: bool = true
@export var debug_gap_alpha: float = 0.22

@export var radial_speed: float = 520.0
@export var chord_speed: float = 760.0
@export var telegraph_time: float = 0.30
@export var travel_time: float = 0.175

var projectile_scene = preload("res://Projectile.tscn")
var radial_telegraph_scene = preload("res://RadialTelegraph.tscn")
var chord_telegraph_scene = preload("res://ChordTelegraph.tscn")

@onready var arena = $"../Arena"
@onready var player = $"../Player"
@onready var telegraphs = $"../Telegraphs"
@onready var projectiles = $"../Projectiles"
@onready var stream = $"../AudioStreamPlayer"
@onready var main = $".."
@onready var camera = $"../Camera2D"
@onready var shock = $"../Shockwave/Line2D"
@onready var particles = $"../BeatParticles"
@onready var background = $"../BGCanvas/Background/Gradient"

var gap_centre = 0.0
var gap_until_t = 0.0

var next_event_index = 0
var next_beat_index = 0

func _ready() -> void:
	gap_centre = (player.global_position - arena.global_position).angle()

func beat(idx):
	arena.pulse()
	if !Config.reduced_motion:
		background.on_beat()
	if idx % 4 == 0:
		if !Config.reduced_motion:
			if Config.camera_fx:
				camera.trigger_beat()
			if Config.shockwave:
				shock.fire(arena.radius, arena.radius + 300, Config.colours["shockwave"])
			if Config.particles:
				particles.global_position = arena.global_position
				particles.process_material.emission_ring_inner_radius = arena.radius + 33
				particles.process_material.emission_ring_radius = arena.radius + 34
				particles.restart()
	elif idx % 4 == 2:
		spawn_radial(randf() * TAU, Config.colours["beat_obstacle"], radial_speed*0.7)

func queue_event(e):
	var base_theta = fmod(e["t"] * 1.321, TAU)
	
	match e["band"].to_lower():
		"low":
			var theta_a = base_theta
			var theta_b = base_theta + PI * 0.22 + e["s"] * 1.5
			spawn_chord(theta_a, theta_b, Config.colours["obstacles"])
		"mid", "high":
			spawn_radial(base_theta, Config.colours["obstacles"])

func _process(_delta: float) -> void:
	gap_width_deg = lerp(max_gap, min_gap, pow(main.energy, 1.12))
	
	if !stream.playing:
		return
	
	var song_time = stream.get_playback_position()
	var lookahead_time = song_time + telegraph_time + travel_time
	
	if song_time > gap_until_t:
		var target = (player.global_position - arena.global_position).angle()
		gap_centre = lerp_angle(gap_centre, target, 0.18)
	
	while next_beat_index < main.beats.size() and main.beats[next_beat_index] <= song_time:
		next_beat_index += 1
		beat(next_beat_index)
	
	while next_event_index < main.events.size():
		var event = main.events[next_event_index]
		if event["t"] <= lookahead_time:
			queue_event(event)
			next_event_index += 1
		else:
			break
	
	if debug_draw_gap:
		queue_redraw()

func lock_gap(time: float) -> void:
	var song_time = stream.get_playback_position()
	gap_until_t = maxf(gap_until_t, song_time+maxf(time, min_gap_window))

func get_gap_width_rad() -> float:
	return deg_to_rad(gap_width_deg)

func get_gap_effective_width_rad() -> float:
	return deg_to_rad(gap_width_deg + 2.0 * gap_margin_deg)

func is_angle_in_gap(theta: float, t: float = -1.0) -> bool:
	var song_time = stream.get_playback_position()
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
	
	var neg = 1.0 if d >= 0.0 else -1.0
	var eps = deg_to_rad(0.5)
	return gap_centre + neg * (half + eps)

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

func spawn_radial(theta: float, colour: Color = Color("d9a0d4"), spd = radial_speed) -> void:
	if is_angle_in_gap(theta):
		theta = nearest_angle_outside_gap(theta)
	
	var centre = arena.global_position
	var r = arena.radius
	var spawn_pos = centre + Vector2(cos(theta), sin(theta)) * r
	var inward = (centre - spawn_pos).normalized()
	
	var tg = radial_telegraph_scene.instantiate()
	telegraphs.add_child(tg)
	tg.setup(centre, spawn_pos, inward, projectile_scene, spd, projectiles, telegraph_time, colour)

func spawn_chord(theta_a: float, theta_b: float, colour: Color = Color("d9a0d4")) -> void:
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
	tg.setup(a, b, projectile_scene, chord_speed, projectiles, telegraph_time, colour)
