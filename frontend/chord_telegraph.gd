extends Node2D

@export var telegraph_time: float = 0.5

var t_left: float
var a: Vector2
var b: Vector2
var projectile_scene: PackedScene
var projectile_speed: float
var projectiles_parent: Node
var col_pro: Color

func setup(_a: Vector2, _b: Vector2, _projectile_scene: PackedScene, _proj_speed: float, _projectiles_parent: Node, _telegraph: float, cr: Color) -> void:
	a = _a
	b = _b
	projectile_scene = _projectile_scene
	projectile_speed = _proj_speed
	projectiles_parent = _projectiles_parent
	telegraph_time = _telegraph
	t_left = telegraph_time
	col_pro = cr

func _process(delta: float) -> void:
	t_left -= delta
	queue_redraw()
	if t_left <= 0.0:
		var p = projectile_scene.instantiate()
		projectiles_parent.add_child(p)
		p.setup_chord(a, b, projectile_speed, col_pro)
		queue_free()

func _draw() -> void:
	var k = clampf(t_left / maxf(telegraph_time, 0.0001), 0.0, 1.0)
	var c = Config.colours["telegraph_chord"]
	c.a = 0.7 * (1.0 - k * 0.4)
	draw_line(a, b, c, 4.0, true)
