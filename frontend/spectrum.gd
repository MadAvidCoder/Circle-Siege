extends Node2D

@export var spectrum_height: float = 900.0
@export var y_offset: float = 0.0
@export var group_size: int = 10

var last_bins = []

@onready var main = $".."
@onready var stream = $"../AudioStreamPlayer"

@onready var width = get_viewport_rect().size.x * 0.98
@onready var x_offset = get_viewport_rect().size.x * 0.02 / 2

func _draw() -> void:
	var time = stream.get_playback_position()
	var bins = main.get_spectrum(time)
	if bins.size() == 0:
		return
	
	if last_bins.size() == 0:
		last_bins = bins.duplicate()
	
	var n_bins = bins.size() * 0.7
	var pts = []
	
	var max_val = 0.0
	for b in bins:
		max_val = max(max_val, b)
	max_val = max(max_val, 1e-6)
	
	for i in range(n_bins):
		last_bins[i] = lerp(last_bins[i], bins[i], 0.18)
	
	for i in range(0, n_bins, group_size):
		var sum = 0.0
		for j in range(group_size):
			if i+j < n_bins:
				sum += last_bins[i+j]
		var avg = sum / group_size
		var db = log(avg + 1e-6)
		var x = width * float(i) / float(n_bins-1) + x_offset
		var y = y_offset - clamp((db + 5.0) / 10.0, 0, 1) * spectrum_height
		pts.append(Vector2(x, y))
	pts.append(Vector2(width * float(n_bins) / float(n_bins-1) + x_offset, y_offset))
	draw_polyline(pts, Color(0.5,0.7,1,0.75), 2.5, true)

func _process(delta: float) -> void:
	queue_redraw()
