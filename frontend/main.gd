extends Node2D

@onready var file_sel = $FileDialog
@onready var popup = $PopupPanel
@onready var popup_label = $PopupPanel/Label

func _ready() -> void:
	file_sel.show()

func _file_selected(path: String) -> void:
	var wav_path = path
	var analyser_path = "C:/Users/Ma Family/Documents/David/Godot/Circle-Seige/backend/target/release/circle_siege_backend.exe"
	var analysis_path = ProjectSettings.globalize_path("user://analysis.jsonl")
	
	popup_label.text = "Processing `" + wav_path.get_file() + "`. \nPlease Wait..."
	popup.popup()

	var res = OS.execute(analyser_path, [
		"analyze-wav",
		"--input", wav_path,
		"--output", analysis_path
	])
	
	popup.hide()
	
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
	
	var meta
	var energies = []
	var events = []
	for r in records:
		match r["type"]:
			"meta": meta = r
			"energy": energies.append(r)
			"event": events.append(r)
		
	var audio = AudioStreamWAV.new()
	var wav_file = FileAccess.open(wav_path, FileAccess.READ)
	$AudioStreamPlayer.stream = AudioStreamWAV.load_from_buffer(wav_file.get_buffer(wav_file.get_length()))
	wav_file.close()
	$AudioStreamPlayer.play()
