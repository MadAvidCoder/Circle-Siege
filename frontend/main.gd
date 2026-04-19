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
@onready var title_1 = $Menu/Control/Siege
@onready var title_2 = $Menu/Control/Slashes
@onready var title_3 = $Menu/Control/Circle
@onready var lives = $LivesDisplay
@onready var director = $Director
@onready var line = $Spectrum

var diffs = {
	"chill": {
		"threshold": 6.5,
		"refractory": [12, 8, 6],
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

var ws = WebSocketPeer.new()
var backend_process
var mode
var beat_index = 0

func _ready() -> void:
	update_colours()

func _process(_delta: float) -> void:
	energy = get_energy($AudioStreamPlayer.get_playback_position())
	if mode != "live":
		return
	ws.poll()
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var packet = ws.get_packet()
			if ws.was_string_packet():
				var packet_text = packet.get_string_from_utf8()
				var record = JSON.parse_string(packet_text)
				match record["type"]:
					"meta": meta = record
					"energy": energy = record["e"]
					"event": director.queue_event(record)
					"spectrum": line.new_data(record)
					"beat":
						beat_index += 1
						director.beat(beat_index)
	
	elif state == WebSocketPeer.STATE_CLOSED:
		# TODO: handle disconnect
		get_tree().reload_current_scene()

func update_colours():
	bg.material.set_shader_parameter("dark_col", Config.colours["bg_dark"])
	bg.material.set_shader_parameter("light_col", Config.colours["bg_light"])
	particles.texture.gradient.set_color(0, Config.colours["shockwave"])
	player_sprite.texture.gradient.set_color(0, Config.colours["player"])
	title_1.add_theme_color_override("font_color", Config.colours["menu"])
	title_2.add_theme_color_override("font_color", Config.colours["menu"])
	title_3.add_theme_color_override("font_color", Config.colours["menu"])

func start(path, difficulty):
	if path == "system":
		start_live(difficulty)
	else:
		start_file(path, difficulty)

func start_live(difficulty: String) -> void:
	var analyser_path = "C:/Users/Ma Family/Documents/David/Godot/Circle-Seige/backend/target/release/circle_siege_backend.exe"
	
	popup_label.text = "Connecting to Websocket.\nPlease Wait..."
	popup.popup_centered()
	
	await get_tree().create_timer(0.1).timeout

	backend_process = OS.create_process(analyser_path, [
		"analyze-live",
		"--port", 9001,
		"--threshold", diffs[difficulty]["threshold"],
		"--refractory", diffs[difficulty]["refractory"][0], diffs[difficulty]["refractory"][1], diffs[difficulty]["refractory"][2]
	], false)
	
	await get_tree().create_timer(0.5).timeout
	while ws.connect_to_url("ws://127.0.0.1:9001") != OK:
		await get_tree().create_timer(0.5).timeout
	
	mode = "live"
	lives.init($Player.lives)
	popup.hide()
	arena.show()
	menu.hide()

func _exit_tree():
	if backend_process and OS.is_process_running(backend_process):
		OS.kill(backend_process)

func start_file(path: String, difficulty: String) -> void:
	mode = "file"
	var wav_path = path
	var analyser_path = "C:/Users/Ma Family/Documents/David/Godot/Circle-Seige/backend/target/release/circle_siege_backend.exe"
	var analysis_path = ProjectSettings.globalize_path("user://analysis.jsonl")
	
	popup_label.text = "Processing `" + wav_path.get_file() + "`. \nPlease Wait..."
	popup.popup_centered()
	
	await get_tree().create_timer(0.1).timeout

	var res = OS.execute(analyser_path, [
		"analyze-wav",
		"--input", wav_path,
		"--output", analysis_path,
		"--threshold", diffs[difficulty]["threshold"],
		"--refractory", diffs[difficulty]["refractory"][0], diffs[difficulty]["refractory"][1], diffs[difficulty]["refractory"][2]
	])
	
	if res != 0:
		print("ERROR")
		get_tree().reload_current_scene()
	
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

	match wav_path.get_extension().to_lower():
		"mp3":
			var mfile = FileAccess.open(path, FileAccess.READ)
			var stream = AudioStreamMP3.new()
			stream.data = mfile.get_buffer(mfile.get_length())
			$AudioStreamPlayer.stream = stream
			mfile.close()
		"wav":
			var mfile = FileAccess.open(path, FileAccess.READ)
			var stream = AudioStreamWAV.load_from_buffer(mfile.get_buffer(mfile.get_length()))
			$AudioStreamPlayer.stream = stream
			mfile.close()
		"ogg":
			var stream = AudioStreamOggVorbis.load_from_file(path)
			$AudioStreamPlayer.stream = stream
		_:
			print("unsupported file type")
			get_tree().reload_current_scene()
	
	lives.init($Player.lives)
	popup.hide()
	arena.show()
	menu.hide()
	$AudioStreamPlayer.play()

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
