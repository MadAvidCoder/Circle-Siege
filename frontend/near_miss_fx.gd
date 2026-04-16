extends Node2D

@export var size = Vector2(54, 54);
@export var duration = 0.10
@export var corner_len = 12.0
@export var colour = Color(1.0, 0.95, 0.7, 1.0)
@export var thickness = 2.0

var t = 0.0
var active = false

func trigger():
	t = 0.0
	active = true
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if !active:
		return
	t += delta
	if t > duration:
		active = false
		visible = false
		return
	queue_redraw()

func _draw() -> void:
	if !active:
		return
	
	var col = colour
	col.a = 1.0 - (t / duration)
	
	var half = size * 0.5
	var tl = Vector2(-half.x, -half.y)
	var _tr = Vector2( half.x, -half.y)
	var bl = Vector2(-half.x,  half.y)
	var br = Vector2( half.x,  half.y)
	
	draw_line(tl, tl + Vector2(corner_len, 0), col, thickness, true)
	draw_line(tl, tl + Vector2(0, corner_len), col, thickness, true)

	draw_line(_tr, _tr + Vector2(-corner_len, 0), col, thickness, true)
	draw_line(_tr, _tr + Vector2(0, corner_len), col, thickness, true)

	draw_line(bl, bl + Vector2(corner_len, 0), col, thickness, true)
	draw_line(bl, bl + Vector2(0, -corner_len), col, thickness, true)

	draw_line(br, br + Vector2(-corner_len, 0), col, thickness, true)
	draw_line(br, br + Vector2(0, -corner_len), col, thickness, true)
