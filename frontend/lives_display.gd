extends Control

@export var square_size: int = 28
@export var spacing: int = 8
@export var margin: int = 12

@export var pulse_scale: float = 1.25
@export var pulse_time: float = 0.12

var squares: Array[ColorRect] = []
var max_lives: int = 0
var current_lives: int = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update_layout()

func init(m_lives: int):
	max_lives = m_lives
	current_lives = max_lives
	create_squares(current_lives)
	update_layout()

func create_squares(num):
	for i in range(num):
		var cr = ColorRect.new()
		cr.color = Config.colours["player"]
		cr.size_flags_horizontal = Control.SIZE_FILL
		cr.size_flags_vertical = Control.SIZE_FILL
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cr)
		squares.append(cr)

func update_layout():
	var total_width = max_lives * square_size + (max_lives - 1) * spacing
	var base_pos = Vector2(get_viewport().get_visible_rect().size.x - margin - total_width, margin)
	
	for i in range(squares.size()):
		var x = base_pos.x + i * (square_size + spacing)
		var y = base_pos.y
		squares[i].position = Vector2(x, y)
		squares[i].size = Vector2(square_size, square_size)

func set_lives(n: int):
	n = clamp(n, 0, max_lives)
	if n < current_lives:
		for idx in range(n, current_lives):
			animate_loss(idx)
	current_lives = n
	refresh_colors(Config.colours["player"])

func animate_loss(idx: int):
	if idx < 0 or idx >= squares.size():
		return
	var node = squares[idx]
	for i in range(3):
		node.color = Config.colours["player_invulnerable"]
		await get_tree().create_timer(0.08).timeout
		node.color = Config.colours["player_inactive"]
		await get_tree().create_timer(0.08).timeout
	
	node.color = Config.colours["player_inactive"]
	
func refresh_colors(colour: Color) -> void:
	for i in range(squares.size()):
		squares[i].color = colour if i < current_lives else Config.colours["player_inactive"]

func show_invulnerable(duration: float) -> void:
	refresh_colors(Config.colours["player_invulnerable"])
	await get_tree().create_timer(duration).timeout
	refresh_colors(Config.colours["player"])
