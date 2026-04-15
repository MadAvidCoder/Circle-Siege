extends Node2D

@export var base_alpha = 0.37
@export var beat_alpha_add = 0.10
@export var rotate_speed = 0.12
@export var beat_fade_in = 0.05
@export var beat_fade_out = 0.18

@onready var glow = $Glow

func _ready() -> void:
	glow.modulate.a = base_alpha

func _process(delta: float) -> void:
	glow.rotation += rotate_speed * delta

func on_beat(strength = 1.0) -> void:
	var t_alpha = clamp(base_alpha + beat_alpha_add * float(strength), 0.0, 0.8)
	
	var tween = create_tween()
	tween.tween_property(glow, "modulate:a", t_alpha, beat_fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", base_alpha, beat_fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
