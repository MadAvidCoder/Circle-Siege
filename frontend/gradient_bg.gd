extends ColorRect

@export var radius := 0.14           # lower = gentler
@export var speed := 0.045           # slower = smoother
@export var energy_follow := 3.5     # higher = more reactive, lower = smoother
@export var beat_decay := 6.0        # how fast beat pulse fades
@export var downbeat_every := 4      # treat every 4 beats as "strong"

var energy := 0.0
var _energy_s := 0.0
var _beat := 0.0
var _beat_count := 0

func _process(delta: float) -> void:
	# Smooth energy so it doesn't jitter the shader
	_energy_s = lerp(_energy_s, energy, 1.0 - exp(-energy_follow * delta))

	_beat = maxf(0.0, _beat - delta * beat_decay)

	var mat := material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("energy", _energy_s)
	mat.set_shader_parameter("beat", _beat)

	var t := Time.get_ticks_msec() * 0.001
	var s := speed * (1.0 + _energy_s * 0.65)

	# VERY slow LFO motion; no randomness => no "jumps"
	mat.set_shader_parameter("p0", Vector2(0.34, 0.38) + Vector2(cos(t*s*0.9),  sin(t*s*0.7))  * radius)
	mat.set_shader_parameter("p1", Vector2(0.70, 0.35) + Vector2(cos(t*s*0.8 + 1.7), sin(t*s*0.6 + 0.9)) * radius)
	mat.set_shader_parameter("p2", Vector2(0.38, 0.72) + Vector2(cos(t*s*0.7 + 3.2), sin(t*s*0.9 + 2.1)) * radius)
	mat.set_shader_parameter("p3", Vector2(0.72, 0.70) + Vector2(cos(t*s*0.6 + 4.1), sin(t*s*0.8 + 3.8)) * radius)

func on_beat(strength := 1.0) -> void:
	_beat_count += 1
	var downbeat = (_beat_count % downbeat_every) == 0
	var k = 1.0 if !downbeat else 1.6
	_beat = clamp(_beat + 0.55 * float(strength) * k, 0.0, 1.0)
