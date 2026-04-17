extends Node2D

var meta
var energies = []
var events = []
var spectrum = []
var beats = []

var energy = 0.0

@onready var file_sel = $FileDialog
@onready var popup = $CanvasLayer/PopupPanel
@onready var popup_label = $CanvasLayer/PopupPanel/Label
@onready var menu = $Menu
@onready var player_sprite = $Player/Sprite2D
@onready var arena = $Arena

@onready var bg = $BGCanvas/Background/Gradient
@onready var particles = $BeatParticles
@onready var title_1 = $Menu/Control/Seige
@onready var title_2 = $Menu/Control/Slashes
@onready var title_3 = $Menu/Control/Circle

var diffs = {
	"chill": {
		"threshold": 7.0,
		"refractory": [14, 10, 6],
	},
	"normal": {
		"threshold": 5.0,
		"refractory": [10, 6, 3],
	},
	"hard": {
		"threshold": 4.2,
		"refractory": [8, 5, 2],
	},
	"insane": {
		"threshold": 3.6,
		"refractory": [6, 4, 1],
	},
}

func update_colours():
	bg.material.set_shader_parameter("dark_col", Config.colours["bg_dark"])
	bg.material.set_shader_parameter("light_col", Config.colours["bg_light"])
	particles.texture.gradient.set_color(0, Config.colours["shockwave"])
	player_sprite.texture.gradient.set_color(0, Config.colours["player"])
	title_1.add_theme_color_override("font_color", Config.colours["menu"])
	title_2.add_theme_color_override("font_color", Config.colours["menu"])
	title_3.add_theme_color_override("font_color", Config.colours["menu"])

func _ready() -> void:
	update_colours()

func start(path: String, difficulty: String) -> void:
	var wav_path = path
	var analyser_path = "C:/Users/Ma Family/Documents/David/Godot/Circle-Seige/backend/target/release/circle_siege_backend.exe"
	var analysis_path = ProjectSettings.globalize_path("user://analysis.jsonl")
	
	popup_label.text = "Processing `" + wav_path.get_file() + "`. \nPlease Wait..."
	popup.popup_centered()
	
	await get_tree().create_timer(0.1).timeout

	OS.execute(analyser_path, [
		"analyze-wav",
		"--input", wav_path,
		"--output", analysis_path,
		"--threshold", diffs[difficulty]["threshold"],
		"--refractory", diffs[difficulty]["refractory"][0], diffs[difficulty]["refractory"][1], diffs[difficulty]["refractory"][2]
	])
	
	var records = []
	var file = FileAccess.open(analysis_path, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges() == "":
			continue
		var parsed = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			records.append(parsed)
	file.close()
	
	for r in records:
		match r["type"]:
			"meta": meta = r
			"energy": energies.append(r)
			"event": events.append(r)
			"spectrum": spectrum.append(r)
			"beat": beats.append(r["t"])

	events.sort_custom(func(a, b): return a["t"] < b["t"])
	energies.sort_custom(func(a, b): return a["t"] < b["t"])
	spectrum.sort_custom(func(a, b): return a["t"] < b["t"])
	beats.sort()

	var wav_file = FileAccess.open(wav_path, FileAccess.READ)
	$AudioStreamPlayer.stream = AudioStreamWAV.load_from_buffer(wav_file.get_buffer(wav_file.get_length()))
	wav_file.close()
	$AudioStreamPlayer.play()
	popup.hide()
	arena.show()
	menu.hide()

func _process(_delta: float) -> void:
	energy = get_energy($AudioStreamPlayer.get_playback_position())

func get_energy(t: float) -> float:
	for i in range(energies.size()-1):
		var t0 = energies[i]["t"]
		var t1 = energies[i+1]["t"]
		if t >= t0 and t <= t1:
			var e0 = energies[i]["e"]
			var e1 = energies[i+1]["e"]
			var f = (t-t0)/(t1-t0)
			return lerp(e0, e1, f)
	return energies[energies.size()-1]["e"] if energies.size() > 0 else 0.0

func get_spectrum(time: float) -> Array:
	for i in range(spectrum.size()-1):
		if time >= spectrum[i]["t"] and time < spectrum[i+1]["t"]:
			var a = spectrum[i]["bins"]
			var b = spectrum[i+1]["bins"]
			var f = (time-spectrum[i]["t"])/(spectrum[i+1]["t"]-spectrum[i]["t"])
			var out = []
			for j in range(a.size()):
				out.append(lerp(a[j], b[j], f))
			return out
	return spectrum[spectrum.size()-1]["bins"] if spectrum.size() > 0 else []


func _on_audio_stream_player_finished() -> void:
	await get_tree().create_timer(3).timeout
	get_tree().reload_current_scene()
