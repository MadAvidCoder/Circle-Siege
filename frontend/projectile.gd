extends Area2D

enum MoveKind {
	RADIAL,
	CHORD
}

@export var speed = 450.0
@export var radius = 8.0
@export var damage = 1

var move_kind = MoveKind.RADIAL

var dir = Vector2.ZERO

var chord_a: Vector2
var chord_b: Vector2
var chord_t = 0.0
var chord_len = 1.0

func setup_radial(start_pos: Vector2, direction: Vector2, spd: float) -> void:
	global_position = start_pos
	move_kind = MoveKind.RADIAL
	dir = direction.normalized()
	speed = spd

func setup_chord(a: Vector2, b: Vector2, spd: float) -> void:
	chord_a = a
	chord_b = b
	global_position = a
	move_kind = MoveKind.CHORD
	speed = spd
	chord_t = 0.0
	chord_len = maxf(a.distance_to(b), 0.001)

func _physics_process(delta: float) -> void:
	match move_kind:
		MoveKind.RADIAL:
			global_position += dir  * speed * delta
		MoveKind.CHORD:
			var ds = speed * delta
			chord_t += ds / chord_len
			if chord_t >= 1.0:
				queue_free()
				return
			global_position = chord_a.lerp(chord_b, chord_t)
	
	if global_position.length() > 5000.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("hit"):
		body.hit()
	queue_free()
