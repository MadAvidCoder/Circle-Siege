extends Node

enum WindowModes {
	FULLSCREEN,
	WINDOWED,
	EXCLUSIVE_FULLSCREEN,
}

enum Palettes {
	CYBER,
	
}

var palette = "Cyber"
var particles = true
var camera_fx = true
var shockwave = true
var spectrum_line = true
var reduced_motion = false
var colourblind = false
var contrast = false
var window_mode = WindowModes.FULLSCREEN

func _ready() -> void:
	match window_mode:
		WindowModes.WINDOWED:
			Config.window_mode = Config.WindowModes.WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var window_size = Vector2i(1280, 720)
			DisplayServer.window_set_size(window_size)
			var screen_size = DisplayServer.screen_get_size()
			DisplayServer.window_set_position((screen_size - window_size) / 2)
		WindowModes.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WindowModes.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
