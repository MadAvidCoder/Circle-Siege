extends Area2D

enum MoveKind {
	RADIAL,
	CHORD
}

@export var speed: float = 450.0
@export var radius: float = 8.0
@export var damage: int = 1

var move_kind = MoveKind.RADIAL

var dir = Vector2.ZERO

var chord_a: Vector2
var chord_b: Vector2
var chord_t: float = 0.0
var chord_len: float = 1.0

var near_missed: bool = false

@onready var main = get_tree().current_scene

func _ready():
	add_to_group("projectiles")

func setup_radial(start_pos: Vector2, direction: Vector2, spd: float, colour: Color = Color("d9a0d4")) -> void:
	global_position = start_pos
	move_kind = MoveKind.RADIAL
	dir = direction.normalized()
	speed = spd
	modulate = colour

func setup_chord(a: Vector2, b: Vector2, spd: float, colour: Color = Color("d9a0d4")) -> void:
	chord_a = a
	chord_b = b
	global_position = a
	move_kind = MoveKind.CHORD
	speed = spd
	chord_t = 0.0
	chord_len = maxf(a.distance_to(b), 0.001)
	modulate = colour

func _physics_process(delta: float) -> void:
	var cur_speed = speed * (0.9 + 0.4 * main.energy)
	match move_kind:
		MoveKind.RADIAL:
			global_position += dir  * cur_speed * delta
		MoveKind.CHORD:
			var ds = cur_speed * delta
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
