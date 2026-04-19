extends Node2D

@export var telegraph_time: float = 0.4

var t_left: float
var arena_centre: Vector2
var spawn_pos: Vector2
var dir: Vector2
var projectile_scene: PackedScene
var projectile_speed: float
var projectiles_parent: Node
var col_pro: Color

func setup(_arena_centre: Vector2, _spawn_pos: Vector2, _dir: Vector2, _projectile_scene: PackedScene, _projectile_speed: float, _projectiles_parent: Node, _telegraph: float, cr: Color = Color("d9a0d4")) -> void:
	arena_centre = _arena_centre
	spawn_pos = _spawn_pos
	dir = _dir.normalized()
	projectile_speed = _projectile_speed
	projectile_scene = _projectile_scene
	projectiles_parent = _projectiles_parent
	telegraph_time = _telegraph
	t_left = telegraph_time
	global_position = Vector2.ZERO
	col_pro = cr

func _process(delta: float) -> void:
	t_left -= delta
	queue_redraw()
	if t_left <= 0.0:
		var p = projectile_scene.instantiate()
		projectiles_parent.add_child(p)
		p.setup_radial(spawn_pos, dir, projectile_speed, col_pro)
		queue_free()

func _draw() -> void:
	var alpha = clampf(t_left / maxf(telegraph_time, 0.0001), 0.0, 1.0)
	var c = Config.colours["telegraph_radial"]
	c.a = 0.7 * (1.0 - alpha * 0.3)
	draw_line(spawn_pos, spawn_pos + dir * 36.0, c, 3.0, true)
	draw_circle(spawn_pos, 5.0, c)
